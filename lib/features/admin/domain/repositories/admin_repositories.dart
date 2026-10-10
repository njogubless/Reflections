import 'dart:io';

import '../../../../core/domain/content_status.dart';
import '../../../../core/media/media_storage.dart';
import '../../../../core/pagination/paged.dart';
import '../../../articles/domain/entities/article.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../books/domain/entities/book.dart';
import '../../../qa/domain/entities/question.dart';
import '../../../recording/domain/entities/recording_status.dart';
import '../../../recording/domain/entities/recording_submission.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../entities/activity_entry.dart';

/// Admin-uploaded sermon management. Never touches user submissions.
abstract class AdminSermonRepository {
  String newId();
  Future<PageResult<Sermon>> fetchAll({
    ContentStatus? status,
    Object? cursor,
    int limit = 20,
  });
  Stream<Sermon?> watch(String id);

  /// Creates (status `draft`, sourceType `admin_published`) or updates metadata.
  Future<void> saveMetadata(
    Sermon sermon,
    AppUser admin, {
    required bool isNew,
  });

  UploadHandle uploadAudio(String sermonId, File file, String contentType);
  Future<void> attachAudio(
    String sermonId, {
    required int durationSeconds,
    required int sizeBytes,
  });
  UploadHandle uploadCover(String sermonId, File file, String contentType);
  Future<void> attachCover(String sermonId);

  Future<void> setStatus(Sermon sermon, ContentStatus next, AppUser admin);
}

/// Review of user-recorded submissions. Separate from [AdminSermonRepository].
abstract class RecordingReviewRepository {
  Future<PageResult<RecordingSubmission>> fetchQueue(
    Set<RecordingStatus> statuses, {
    Object? cursor,
    int limit = 20,
  });
  Stream<RecordingSubmission?> watch(String id);

  /// `submitted -> under_review`.
  Future<void> startReview(String recordingId, AppUser admin);

  /// `under_review -> approved | rejected | changes_requested`.
  Future<void> decide(
    String recordingId,
    RecordingStatus decision,
    AppUser admin, {
    String? feedback,
  });

  /// `approved -> published`; creates `sermons/rec_{id}` exactly once.
  Future<String> publish(
    RecordingSubmission recording,
    AppUser admin, {
    required String category,
    String? scriptureQuote,
  });
}

abstract class AdminBookRepository {
  String newId();
  Future<PageResult<Book>> fetchAll({
    ContentStatus? status,
    Object? cursor,
    int limit = 20,
  });
  Stream<Book?> watch(String id);
  Future<void> saveMetadata(Book book, AppUser admin, {required bool isNew});
  UploadHandle uploadDocument(String bookId, File file);
  Future<void> attachDocument(String bookId, {required int sizeBytes});
  UploadHandle uploadCover(String bookId, File file, String contentType);
  Future<void> attachCover(String bookId);
  Future<void> setStatus(Book book, ContentStatus next, AppUser admin);
}

abstract class AdminArticleRepository {
  String newId();
  Future<PageResult<Article>> fetchAll({
    ContentStatus? status,
    Object? cursor,
    int limit = 20,
  });
  Stream<Article?> watch(String id);
  Future<void> save(Article article, AppUser admin, {required bool isNew});
  UploadHandle uploadCover(String articleId, File file, String contentType);
  Future<void> attachCover(String articleId);
  Future<void> setStatus(Article article, ContentStatus next, AppUser admin);
}

abstract class AdminQaRepository {
  Future<PageResult<Question>> fetchInbox(
    QuestionStatus status, {
    Object? cursor,
    int limit = 20,
  });
  Stream<Question?> watchQuestion(String id);
  Stream<OfficialAnswer?> watchAnswer(String questionId);
  Future<void> saveDraftAnswer(String questionId, String body, AppUser admin);

  /// Publishes the official answer and marks the question answered atomically.
  Future<void> publishAnswer(Question question, String body, AppUser admin);

  /// Withdraws a published answer; the question returns to `open`.
  Future<void> unpublishAnswer(Question question, AppUser admin);
  Future<void> setQuestionStatus(
    Question question,
    QuestionStatus next,
    AppUser admin,
  );
}

abstract class AdminDashboardRepository {
  Future<DashboardMetrics> metrics();
  Stream<List<ActivityEntry>> recentActivity({int limit = 10});
}
