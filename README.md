# Devotion — Reflections of Faith

Flutter (Android/iOS) app for sermon audio, user-recorded sermon submissions, books, articles and community Q&A, with a protected admin workspace. Backend: Firebase Auth, Cloud Firestore, Cloud Storage and Cloud Functions.

Specification: [`claude.md`](claude.md) · Assessment and plan: [`docs/implementation-plan.md`](docs/implementation-plan.md) · UI reference: [`stitch_devotion_reflections_of_faith/`](stitch_devotion_reflections_of_faith/)

---

## Quick start (local emulators, no Firebase project needed)

Requirements: Flutter 3.41+ (Dart 3.11), Node 22, Java 21, Firebase CLI.

```bash
flutter pub get
npm --prefix functions install && npm --prefix functions run build
firebase emulators:start --project demo-devotion           # Auth, Firestore, Storage, Functions, UI on :4000

# In another terminal (Android emulator reaches the host at 10.0.2.2 by default):
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
# Physical device on the same network:
flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=EMULATOR_HOST=192.168.x.y
```

Emulator mode is ignored in release builds. Register an account in the app, then make it an admin:

```bash
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-devotion \
  node functions/scripts/set-role.js you@example.com admin
```

Then in the app: **Profile → Refresh account permissions**.

## Connecting a real Firebase project

1. Create the project; enable **Email/Password** sign-in; create Firestore (Native) and the default Storage bucket.
2. `flutterfire configure` — replaces the placeholder `lib/firebase_options.dart` (until then the app shows a "Firebase setup required" screen).
3. `firebase use --add` (replaces the `demo-devotion` default in `.firebaserc`).
4. Deploy rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes,storage`
5. Deploy functions (requires the **Blaze** plan): `firebase deploy --only functions`
6. Grant the first admin with a service-account key held outside the repo:
   `GOOGLE_APPLICATION_CREDENTIALS=/secure/key.json node functions/scripts/set-role.js admin@example.org admin`

Without Cloud Functions the app still works, but notifications are not created, server-side duration checks do not run, and download tokens are not rotated on unpublish.

## Architecture

Feature-based Clean Architecture with Riverpod 3 (no code generation) and go_router.

```
lib/
  app/        bootstrap (Firebase/emulators), router (auth + role redirect, shell), theme (Stitch tokens)
  core/       errors (AppException), media (Storage paths, uploads, file picking), pagination,
              utils (validators, keywords, formatters), shared widgets (state views, cards, chips)
  features/
    auth/           AppUser, roles from ID-token claims, sign-in/register/reset
    home/           dashboard, Read tab, header actions, daily verse (public-domain WEB)
    sermons/        published catalogue, player controller (just_audio), mini-player
    recording/      studio controller (record), local drafts, submissions, history
    books/          PDF library + reader (pdfrx)
    articles/       structured-block articles (no HTML)
    qa/             questions, official answers
    admin/          dashboard, sermon uploads, recording reviews, books, articles, Q&A inbox
    profile/        profile, account actions
    notifications/  in-app notification inbox
```

- Widgets never call Firebase; they use controllers/providers over repository contracts (`domain/repositories`) implemented in `data/`.
- **Two separate audio capabilities.** Playback (`sermons/`: `AudioPlayerController`, `AudioPlaybackEngine`) and recording (`recording/`: `RecordingStudioController`, `AudioRecorderService`, `DraftRepository`, `SubmissionRepository`). Admin *uploads* (`AdminSermonRepository`) and recording *reviews* (`RecordingReviewRepository`) have separate routes, screens, controllers and repositories.
- Errors are mapped to `AppException` (validation / permission / network / notFound / conflict / auth / unexpected); raw Firebase messages never reach the UI.

## Authorization

- Roles (`admin`, `minister`) are **Firebase Auth custom claims** set only by `functions/scripts/set-role.js` (Admin SDK). `users/{uid}.role` is a read-only mirror; rules reject any client write containing `role`.
- The router redirects non-admins away from `/admin/**` (including deep links), every admin page re-checks via `AdminGate`, and **Firestore/Storage rules are the actual boundary**.
- Recording eligibility: any signed-in user (`RecordingPolicy.canRecord` / rule `canSubmitRecordings()`); every submission is reviewed.

## Routes

| Path | Screen |
|---|---|
| `/home`, `/sermons`, `/read`, `/questions`, `/profile` | Tab shell with mini-player |
| `/sermons/:id` | Sermon player |
| `/studio[?resubmit=id]`, `/studio/submit/:draftId` | Recording studio, review & submit |
| `/recordings`, `/recordings/:id` | Drafts + submission history, submission detail/resubmit |
| `/books/:id`, `/books/:id/read`, `/articles/:id` | Book detail, PDF reader, article reader |
| `/questions/ask`, `/questions/mine`, `/questions/:id` | Ask, my questions, question detail |
| `/notifications`, `/profile/edit` | Notifications, edit profile |
| `/admin` … `/admin/{sermons,reviews,books,articles,questions}[/new\|/:id]` | Admin workspace |

## Data model

| Collection | Notes |
|---|---|
| `users/{uid}` | Profile; `role` mirror is server-written only. Subcollection `notifications/{id}` (server-created; owner may set `readAt`). |
| `sermons/{id}` | Public catalogue. `sourceType` = `admin_published` \| `user_submission` (immutable). `status` = `draft/published/unpublished/archived`. User submissions publish as `sermons/rec_{recordingId}` (deterministic ⇒ idempotent). |
| `recordings/{id}` | User submissions, private to owner + admins. `submitted → under_review → approved → published`; `under_review → changes_requested → submitted`; `under_review → rejected`. |
| `books/{id}`, `articles/{id}` | Admin-managed, draft/published lifecycle. Books: PDF only. Articles: `blocks[]` of `{t: p\|h\|q\|s, x, r?}`. |
| `questions/{id}` + `answers/official` | Private by default; askers may opt in to community visibility. Status `answered` is only valid together with a published official answer (enforced with `getAfter`). |
| `admin_activity/{id}` | Append-only admin audit log (dashboard "Recent activity"). |

Composite indexes: [`firestore.indexes.json`](firestore.indexes.json). Search uses a lowercased `keywords` array with `array-contains` (single most selective token).

### Storage

| Path | Write | Read |
|---|---|---|
| `sermons/published/{id}/{audio\|cover}` | admin (audio ≤ 200 MB, image ≤ 5 MB) | admin, or signed-in if sermon published |
| `recordings/{uid}/{id}/audio` | owner, audio ≤ 25 MB, only before submission or while `changes_requested` | owner, admin, or signed-in once `sermons/rec_{id}` is published |
| `books/{id}/{document\|cover}` | admin (PDF ≤ 50 MB) | admin, or signed-in if published |
| `articles/{id}/cover` | admin | admin, or signed-in if published |

Documents store storage **paths**; download URLs are resolved on demand. When content leaves publication, `onSermonWritten`/`onBookWritten`/`onArticleWritten` rotate download tokens so previously issued URLs stop working.

## Workflows

**User recording:** permission → record (monotonic timer, pause/resume, interruption auto-pause, background auto-pause, hard stop at 20:00) → local draft (survives navigation away mid-take) → preview + metadata → explicit submit (resumable upload with progress/cancel/retry; same storage path and document ID on retry) → admin review → publish. `onRecordingWritten` re-measures the uploaded audio and returns over-length submissions as `changes_requested`.

**Admin upload:** create draft → upload audio (duration probed locally) and optional cover → publish / unpublish / archive.

**Q&A:** ask → admin drafts and publishes the official answer (question becomes `answered` atomically) → asker notified (`onAnswerWritten`). Admins may withdraw an answer or close/reopen a question.

## Testing

```bash
flutter analyze
flutter test                                    # unit + widget tests
npm --prefix functions test                     # Cloud Functions logic
npm --prefix test_rules install
firebase emulators:exec --only firestore,storage --project demo-devotion "npm --prefix test_rules test"
```

## Known limitations

- **Push notifications (FCM) are not implemented.** Notifications are in-app records created by Cloud Functions.
- **Background playback** (lock-screen controls, playback while the app is backgrounded on iOS) is not configured; it needs `just_audio_background` / `audio_service` and platform setup.
- **Recording** auto-pauses when the app is backgrounded (iOS requires a background audio mode to continue). If the process is killed mid-take, the partial M4A may be unplayable.
- Search is token-based (`array-contains`), not full-text; search and category filters are not combined.
- Public community questions expose the asker's opaque `ownerUid` in the document (never name or email). A server-maintained public projection would remove it.
- Books: PDF only. No bookmarks or saved/favourited content yet.
- Download URLs remain valid until rotation runs (requires deployed Functions).
- iOS builds have not been run in this environment (no macOS); the Podfile and Info.plist are configured.
