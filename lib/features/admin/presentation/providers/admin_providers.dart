import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/media/media_storage.dart';
import '../../../../core/pagination/paged.dart';
import '../../../articles/domain/entities/article.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../books/domain/entities/book.dart';
import '../../../qa/domain/entities/question.dart';
import '../../../recording/domain/entities/recording_status.dart';
import '../../../recording/domain/entities/recording_submission.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../../data/repositories/admin_content_repositories_impl.dart';
import '../../data/repositories/admin_sermon_repository_impl.dart';
import '../../data/repositories/recording_review_repository_impl.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/repositories/admin_repositories.dart';

final adminSermonRepositoryProvider = Provider<AdminSermonRepository>(
  (ref) => FirestoreAdminSermonRepository(
    ref.watch(firestoreProvider),
    ref.watch(mediaStorageProvider),
  ),
);

final recordingReviewRepositoryProvider = Provider<RecordingReviewRepository>(
  (ref) => FirestoreRecordingReviewRepository(ref.watch(firestoreProvider)),
);

final adminBookRepositoryProvider = Provider<AdminBookRepository>(
  (ref) => FirestoreAdminBookRepository(
    ref.watch(firestoreProvider),
    ref.watch(mediaStorageProvider),
  ),
);

final adminArticleRepositoryProvider = Provider<AdminArticleRepository>(
  (ref) => FirestoreAdminArticleRepository(
    ref.watch(firestoreProvider),
    ref.watch(mediaStorageProvider),
  ),
);

final adminQaRepositoryProvider = Provider<AdminQaRepository>(
  (ref) => FirestoreAdminQaRepository(ref.watch(firestoreProvider)),
);

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>(
  (ref) => FirestoreAdminDashboardRepository(ref.watch(firestoreProvider)),
);

/// The signed-in admin, or a permission error. Admin controllers call this
/// before every mutation (rules enforce the same server-side).
AppUser requireAdmin(Ref ref) {
  final user = ref.read(currentUserProvider);
  if (user == null || !user.isAdmin) throw const AppException.permission();
  return user;
}

// ---------------------------------------------------------------- dashboard

final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>(
  (ref) => ref.watch(adminDashboardRepositoryProvider).metrics(),
);

final recentActivityProvider = StreamProvider.autoDispose<List<ActivityEntry>>(
  (ref) => ref.watch(adminDashboardRepositoryProvider).recentActivity(),
);

// ---------------------------------------------------------------- lists

class AdminSermonList extends PagedNotifier<Sermon> {
  AdminSermonList(this.status);
  final ContentStatus? status;

  @override
  Future<PageResult<Sermon>> fetchPage(Object? cursor, int limit) => ref
      .read(adminSermonRepositoryProvider)
      .fetchAll(status: status, cursor: cursor, limit: limit);
}

final adminSermonListProvider = NotifierProvider.autoDispose
    .family<AdminSermonList, PagedState<Sermon>, ContentStatus?>(
      AdminSermonList.new,
    );

class ReviewQueue extends PagedNotifier<RecordingSubmission> {
  ReviewQueue(this.filter);
  final ReviewFilter filter;

  @override
  Future<PageResult<RecordingSubmission>> fetchPage(
    Object? cursor,
    int limit,
  ) => ref
      .read(recordingReviewRepositoryProvider)
      .fetchQueue(filter.statuses, cursor: cursor, limit: limit);
}

enum ReviewFilter {
  pending('Pending', {RecordingStatus.submitted, RecordingStatus.underReview}),
  approved('Approved', {RecordingStatus.approved}),
  returned('Returned', {RecordingStatus.changesRequested}),
  closed('Closed', {RecordingStatus.rejected, RecordingStatus.published});

  const ReviewFilter(this.label, this.statuses);
  final String label;
  final Set<RecordingStatus> statuses;
}

final reviewQueueProvider = NotifierProvider.autoDispose
    .family<ReviewQueue, PagedState<RecordingSubmission>, ReviewFilter>(
      ReviewQueue.new,
    );

final reviewSubmissionProvider = StreamProvider.autoDispose
    .family<RecordingSubmission?, String>(
      (ref, id) => ref.watch(recordingReviewRepositoryProvider).watch(id),
    );

class AdminBookList extends PagedNotifier<Book> {
  AdminBookList(this.status);
  final ContentStatus? status;

  @override
  Future<PageResult<Book>> fetchPage(Object? cursor, int limit) => ref
      .read(adminBookRepositoryProvider)
      .fetchAll(status: status, cursor: cursor, limit: limit);
}

final adminBookListProvider = NotifierProvider.autoDispose
    .family<AdminBookList, PagedState<Book>, ContentStatus?>(AdminBookList.new);

class AdminArticleList extends PagedNotifier<Article> {
  AdminArticleList(this.status);
  final ContentStatus? status;

  @override
  Future<PageResult<Article>> fetchPage(Object? cursor, int limit) => ref
      .read(adminArticleRepositoryProvider)
      .fetchAll(status: status, cursor: cursor, limit: limit);
}

final adminArticleListProvider = NotifierProvider.autoDispose
    .family<AdminArticleList, PagedState<Article>, ContentStatus?>(
      AdminArticleList.new,
    );

class QuestionInbox extends PagedNotifier<Question> {
  QuestionInbox(this.status);
  final QuestionStatus status;

  @override
  Future<PageResult<Question>> fetchPage(Object? cursor, int limit) => ref
      .read(adminQaRepositoryProvider)
      .fetchInbox(status, cursor: cursor, limit: limit);
}

final questionInboxProvider = NotifierProvider.autoDispose
    .family<QuestionInbox, PagedState<Question>, QuestionStatus>(
      QuestionInbox.new,
    );

final adminSermonProvider = StreamProvider.autoDispose.family<Sermon?, String>(
  (ref, id) => ref.watch(adminSermonRepositoryProvider).watch(id),
);
final adminBookProvider = StreamProvider.autoDispose.family<Book?, String>(
  (ref, id) => ref.watch(adminBookRepositoryProvider).watch(id),
);
final adminArticleProvider = StreamProvider.autoDispose
    .family<Article?, String>(
      (ref, id) => ref.watch(adminArticleRepositoryProvider).watch(id),
    );
final adminQuestionProvider = StreamProvider.autoDispose
    .family<Question?, String>(
      (ref, id) => ref.watch(adminQaRepositoryProvider).watchQuestion(id),
    );
final adminAnswerProvider = StreamProvider.autoDispose
    .family<OfficialAnswer?, String>(
      (ref, id) => ref.watch(adminQaRepositoryProvider).watchAnswer(id),
    );

/// Refreshes every admin list and the dashboard after a mutation.
void invalidateAdminLists(Ref ref) {
  ref
    ..invalidate(adminSermonListProvider)
    ..invalidate(reviewQueueProvider)
    ..invalidate(adminBookListProvider)
    ..invalidate(adminArticleListProvider)
    ..invalidate(questionInboxProvider)
    ..invalidate(dashboardMetricsProvider);
}

// ---------------------------------------------------------------- actions

/// Runs one admin mutation at a time with explicit loading/error state.
/// Prevents duplicate submissions from repeated taps.
class AdminAction extends Notifier<AsyncValue<void>> {
  AdminAction(this.key);

  /// Scope key, e.g. `review:<id>` — one in-flight action per scope.
  final String key;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> run(Future<void> Function(AppUser admin) action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final admin = requireAdmin(ref);
      await action(admin);
      if (!ref.mounted) return true;
      invalidateAdminLists(ref);
      state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (ref.mounted) state = AsyncError(AppException.from(e, s), s);
      return false;
    }
  }
}

final adminActionProvider = NotifierProvider.autoDispose
    .family<AdminAction, AsyncValue<void>, String>(AdminAction.new);

// ---------------------------------------------------------------- uploads

class UploadSlotState {
  const UploadSlotState({
    this.progress,
    this.error,
    this.fileName,
    this.done = false,
  });

  final UploadProgress? progress;
  final AppException? error;
  final String? fileName;
  final bool done;

  bool get busy => progress != null && !done && error == null;
}

/// A single file upload (pick → validate → upload → attach) with progress,
/// cancel and retry. Retries reuse the same storage path (no duplicates).
class UploadSlot extends Notifier<UploadSlotState> {
  UploadSlot(this.key);
  final String key;

  UploadHandle? _handle;
  StreamSubscription<UploadProgress>? _sub;
  Future<void> Function()? _lastRun;
  bool _uploading = false; // readable during dispose, unlike `state`

  @override
  UploadSlotState build() {
    ref.onDispose(() {
      _sub?.cancel();
      if (_uploading) _handle?.cancel();
    });
    return const UploadSlotState();
  }

  Future<bool> run({
    required String fileName,
    required UploadHandle Function() start,
    required Future<void> Function() attach,
  }) async {
    if (state.busy) return false;
    var ok = false;
    Future<void> attempt() async {
      try {
        requireAdmin(ref);
        state = UploadSlotState(
          fileName: fileName,
          progress: const UploadProgress(
            phase: UploadPhase.running,
            bytesTransferred: 0,
            totalBytes: 0,
          ),
        );
        final handle = start();
        _handle = handle;
        _uploading = true;
        await _sub?.cancel();
        _sub = handle.progress.listen((p) {
          if (ref.mounted && !state.done) {
            state = UploadSlotState(fileName: fileName, progress: p);
          }
        });
        try {
          await handle.done;
        } finally {
          _uploading = false;
        }
        await attach();
        if (!ref.mounted) return;
        state = UploadSlotState(
          fileName: fileName,
          done: true,
          progress: const UploadProgress(
            phase: UploadPhase.success,
            bytesTransferred: 1,
            totalBytes: 1,
          ),
        );
        ok = true;
      } catch (e, s) {
        if (ref.mounted) {
          state = UploadSlotState(
            fileName: fileName,
            error: AppException.from(e, s),
          );
        }
      }
    }

    _lastRun = attempt;
    await attempt();
    return ok;
  }

  Future<void> retry() async => _lastRun?.call();

  Future<void> cancel() async {
    await _handle?.cancel();
  }

  void fail(AppException e) => state = UploadSlotState(error: e);

  void reset() => state = const UploadSlotState();
}

final uploadSlotProvider = NotifierProvider.autoDispose
    .family<UploadSlot, UploadSlotState, String>(UploadSlot.new);
