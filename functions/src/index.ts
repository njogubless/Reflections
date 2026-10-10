import { randomUUID } from 'node:crypto';

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { parseBuffer } from 'music-metadata';

import {
  checkDuration,
  leftPublication,
  PlannedNotification,
  recordingNotifications,
  RecordingSnapshot,
} from './logic';

initializeApp();
const db = getFirestore();

const REGION = 'us-central1';
const MAX_ADMIN_FANOUT = 25;

async function deliver(notes: PlannedNotification[]): Promise<void> {
  for (const n of notes) {
    const recipients =
      n.recipientUid === 'admins'
        ? (await db.collection('users').where('role', '==', 'admin').limit(MAX_ADMIN_FANOUT).get()).docs.map((d) => d.id)
        : [n.recipientUid];
    await Promise.all(
      recipients.map(async (uid) => {
        try {
          // create() fails if the ID exists: duplicate trigger deliveries are no-ops.
          await db.doc(`users/${uid}/notifications/${n.id}`).create({
            type: n.type,
            title: n.title,
            body: n.body,
            relatedEntityId: n.relatedEntityId,
            readAt: null,
            createdAt: FieldValue.serverTimestamp(),
          });
        } catch (e: unknown) {
          if ((e as { code?: number }).code !== 6 /* ALREADY_EXISTS */) throw e;
        }
      }),
    );
  }
}

/**
 * Recording lifecycle: notifications + server-side duration verification.
 * A submission whose real audio exceeds 20 minutes (or cannot be read) is
 * returned to the owner as `changes_requested` by the trusted backend.
 */
export const onRecordingWritten = onDocumentWritten(
  { document: 'recordings/{recordingId}', region: REGION },
  async (event) => {
    const id = event.params.recordingId;
    const before = event.data?.before.data() as RecordingSnapshot | undefined;
    const after = event.data?.after.data() as (RecordingSnapshot & { storagePath?: string }) | undefined;

    if (after && after.status === 'submitted' && before?.status !== 'submitted' && after.storagePath) {
      const verdict = await verifyDuration(after.storagePath);
      if (!verdict.ok) {
        logger.warn('recording failed duration check', { id, seconds: verdict.seconds });
        const ref = event.data!.after.ref;
        // Only act if no reviewer has moved it on in the meantime.
        const flagged = await db.runTransaction(async (tx) => {
          const current = await tx.get(ref);
          if (current.get('status') !== 'submitted') return false;
          tx.update(ref, {
            status: 'changes_requested',
            reviewFeedback: verdict.feedback,
            reviewedBy: 'system',
            reviewerName: 'Automatic check',
            reviewedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            ...(verdict.seconds != null ? { durationSeconds: Math.round(verdict.seconds) } : {}),
          });
          return true;
        });
        if (flagged) return; // the follow-up write triggers the changes_requested notice
      } else {
        // Store the measured duration (not the client's claim).
        await event.data!.after.ref.update({ durationSeconds: Math.max(1, Math.round(verdict.seconds)) });
      }
    }

    await deliver(recordingNotifications(id, before, after));
  },
);

async function verifyDuration(storagePath: string) {
  try {
    const [buffer] = await getStorage().bucket().file(storagePath).download();
    const meta = await parseBuffer(buffer, { mimeType: 'audio/mp4' }, { duration: true });
    return checkDuration(meta.format.duration);
  } catch (e) {
    logger.error('duration probe failed', { storagePath, error: String(e) });
    return checkDuration(null);
  }
}

/** Notify the asker when an official answer is published. */
export const onAnswerWritten = onDocumentWritten(
  { document: 'questions/{questionId}/answers/{answerId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || after.status !== 'published' || before?.status === 'published') return;
    const qid = event.params.questionId;
    const question = (await db.doc(`questions/${qid}`).get()).data();
    if (!question) return;
    const stamp = (after.publishedAt?.toMillis?.() as number | undefined) ?? Date.now();
    await deliver([{
      id: `${qid}_answered_${stamp}`,
      recipientUid: question.ownerUid,
      type: 'question_answered',
      title: 'Your question was answered',
      body: `“${question.title}” has an official answer.`,
      relatedEntityId: qid,
    }]);
  },
);

/**
 * Firebase download URLs are bearer tokens. When content leaves publication,
 * rotate the tokens so previously issued URLs stop working.
 */
async function rotateTokens(paths: Array<string | null | undefined>) {
  const bucket = getStorage().bucket();
  await Promise.all(
    paths.filter((p): p is string => !!p).map(async (p) => {
      try {
        await bucket.file(p).setMetadata({ metadata: { firebaseStorageDownloadTokens: randomUUID() } });
      } catch (e) {
        logger.warn('token rotation skipped', { path: p, error: String(e) });
      }
    }),
  );
}

export const onSermonWritten = onDocumentWritten(
  { document: 'sermons/{sermonId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!leftPublication(before, after)) return;
    await rotateTokens([after?.storagePath, after?.coverStoragePath]);
  },
);

export const onBookWritten = onDocumentWritten(
  { document: 'books/{bookId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!leftPublication(before, after)) return;
    await rotateTokens([after?.fileStoragePath, after?.coverStoragePath]);
  },
);

export const onArticleWritten = onDocumentWritten(
  { document: 'articles/{articleId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!leftPublication(before, after)) return;
    await rotateTokens([after?.coverStoragePath]);
  },
);
