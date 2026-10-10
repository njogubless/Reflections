import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/media_storage.dart';
import '../../../../core/pagination/paged.dart';
import '../../../../core/utils/validators.dart';
import '../../../articles/data/article_data.dart';
import '../../../articles/domain/entities/article.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../books/data/book_data.dart';
import '../../../books/domain/entities/book.dart';
import '../../../qa/data/qa_data.dart';
import '../../../qa/domain/entities/question.dart';
import '../../../recording/data/models/recording_model.dart';
import '../../../recording/domain/entities/recording_status.dart';
import '../../../sermons/data/models/sermon_model.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../activity_log.dart';

Future<PageResult<T>> _page<T>(
  Query<Map<String, dynamic>> q,
  T Function(String, Map<String, dynamic>) map,
  Object? cursor,
  int limit,
) async {
  var query = q;
  if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);
  query = query.limit(limit);
  final snap = await query.get();
  return PageResult(
    snap.docs.map((d) => map(d.id, d.data())).toList(),
    cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
    hasMore: snap.docs.length == limit,
  );
}

void _checkTransition(ContentStatus from, ContentStatus to) {
  if (!from.canTransitionTo(to)) {
    throw AppException.conflict(
      'Cannot move from ${from.label.toLowerCase()} to ${to.label.toLowerCase()}.',
    );
  }
}

class FirestoreAdminBookRepository implements AdminBookRepository {
  FirestoreAdminBookRepository(this._db, this._media);

  final FirebaseFirestore _db;
  final MediaStorage _media;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(BookModel.collection);

  @override
  String newId() => _col.doc().id;

  @override
  Future<PageResult<Book>> fetchAll({
    ContentStatus? status,
    Object? cursor,
    int limit = 20,
  }) => guard(() {
    Query<Map<String, dynamic>> q = _col;
    if (status != null) q = q.where('status', isEqualTo: status.wire);
    return _page(
      q.orderBy('updatedAt', descending: true),
      BookModel.fromMap,
      cursor,
      limit,
    );
  });

  @override
  Stream<Book?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? BookModel.fromMap(s.id, s.data()!)
            : null,
      );

  @override
  Future<void> saveMetadata(Book book, AppUser admin, {required bool isNew}) =>
      guard(() async {
        if (book.title.trim().isEmpty) {
          throw const AppException.validation('A title is required.');
        }
        final batch = _db.batch();
        final data = {
          ...BookModel.metadataMap(book),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isNew) {
          batch.set(_col.doc(book.id), {
            ...data,
            'status': ContentStatus.draft.wire,
            'coverStoragePath': null,
            'fileStoragePath': null,
            'fileFormat': null,
            'fileSizeBytes': 0,
            'uploadedBy': admin.uid,
            'publishedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
          ActivityLog.addToBatch(
            _db,
            batch,
            admin,
            action: 'book.created',
            entityType: 'book',
            entityId: book.id,
            summary: 'Created book draft “${book.title.trim()}”',
          );
        } else {
          batch.update(_col.doc(book.id), data);
        }
        await batch.commit();
      });

  @override
  UploadHandle uploadDocument(String bookId, File file) => _media.uploadFile(
    storagePath: BookPaths.document(bookId),
    file: file,
    contentType: BookFormat.pdf.mimeType,
  );

  @override
  Future<void> attachDocument(String bookId, {required int sizeBytes}) => guard(
    () => _col.doc(bookId).update({
      'fileStoragePath': BookPaths.document(bookId),
      'fileFormat': BookFormat.pdf.wire,
      'fileSizeBytes': sizeBytes,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  UploadHandle uploadCover(String bookId, File file, String contentType) =>
      _media.uploadFile(
        storagePath: BookPaths.cover(bookId),
        file: file,
        contentType: contentType,
      );

  @override
  Future<void> attachCover(String bookId) => guard(
    () => _col.doc(bookId).update({
      'coverStoragePath': BookPaths.cover(bookId),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> setStatus(Book book, ContentStatus next, AppUser admin) =>
      guard(() async {
        _checkTransition(book.status, next);
        if (next == ContentStatus.published && !book.isReadable) {
          throw const AppException.validation(
            'Upload the PDF before publishing.',
          );
        }
        final batch = _db.batch();
        batch.update(_col.doc(book.id), {
          'status': next.wire,
          if (next == ContentStatus.published && book.publishedAt == null)
            'publishedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ActivityLog.addToBatch(
          _db,
          batch,
          admin,
          action: 'book.${next.wire}',
          entityType: 'book',
          entityId: book.id,
          summary: '${next.label} book “${book.title}”',
        );
        await batch.commit();
      });
}

class FirestoreAdminArticleRepository implements AdminArticleRepository {
  FirestoreAdminArticleRepository(this._db, this._media);

  final FirebaseFirestore _db;
  final MediaStorage _media;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(ArticleModel.collection);

  @override
  String newId() => _col.doc().id;

  @override
  Future<PageResult<Article>> fetchAll({
    ContentStatus? status,
    Object? cursor,
    int limit = 20,
  }) => guard(() {
    Query<Map<String, dynamic>> q = _col;
    if (status != null) q = q.where('status', isEqualTo: status.wire);
    return _page(
      q.orderBy('updatedAt', descending: true),
      ArticleModel.fromMap,
      cursor,
      limit,
    );
  });

  @override
  Stream<Article?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? ArticleModel.fromMap(s.id, s.data()!)
            : null,
      );

  @override
  Future<void> save(Article article, AppUser admin, {required bool isNew}) =>
      guard(() async {
        if (article.title.trim().isEmpty) {
          throw const AppException.validation('A title is required.');
        }
        final bodyLength = article.blocks.fold<int>(
          0,
          (n, b) => n + b.text.length,
        );
        if (bodyLength > Limits.articleBodyMax) {
          throw const AppException.validation('The article body is too long.');
        }
        final batch = _db.batch();
        final data = {
          ...ArticleModel.contentMap(article),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isNew) {
          batch.set(_col.doc(article.id), {
            ...data,
            'status': ContentStatus.draft.wire,
            'authorId': admin.uid,
            'authorName': article.authorName.trim().isEmpty
                ? admin.displayName
                : article.authorName.trim(),
            'coverStoragePath': null,
            'publishedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
          ActivityLog.addToBatch(
            _db,
            batch,
            admin,
            action: 'article.created',
            entityType: 'article',
            entityId: article.id,
            summary: 'Created article draft “${article.title.trim()}”',
          );
        } else {
          batch.update(_col.doc(article.id), {
            ...data,
            'authorName': article.authorName.trim(),
          });
        }
        await batch.commit();
      });

  @override
  UploadHandle uploadCover(String articleId, File file, String contentType) =>
      _media.uploadFile(
        storagePath: ArticlePaths.cover(articleId),
        file: file,
        contentType: contentType,
      );

  @override
  Future<void> attachCover(String articleId) => guard(
    () => _col.doc(articleId).update({
      'coverStoragePath': ArticlePaths.cover(articleId),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> setStatus(Article article, ContentStatus next, AppUser admin) =>
      guard(() async {
        _checkTransition(article.status, next);
        if (next == ContentStatus.published && article.blocks.isEmpty) {
          throw const AppException.validation(
            'Write the article body before publishing.',
          );
        }
        final batch = _db.batch();
        batch.update(_col.doc(article.id), {
          'status': next.wire,
          if (next == ContentStatus.published && article.publishedAt == null)
            'publishedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ActivityLog.addToBatch(
          _db,
          batch,
          admin,
          action: 'article.${next.wire}',
          entityType: 'article',
          entityId: article.id,
          summary: '${next.label} article “${article.title}”',
        );
        await batch.commit();
      });
}

class FirestoreAdminQaRepository implements AdminQaRepository {
  FirestoreAdminQaRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(QaModel.questions);

  @override
  Future<PageResult<Question>> fetchInbox(
    QuestionStatus status, {
    Object? cursor,
    int limit = 20,
  }) => guard(
    () => _page(
      _col
          .where('status', isEqualTo: status.wire)
          .orderBy('createdAt', descending: status != QuestionStatus.open),
      QaModel.questionFromMap,
      cursor,
      limit,
    ),
  );

  @override
  Stream<Question?> watchQuestion(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? QaModel.questionFromMap(s.id, s.data()!)
            : null,
      );

  @override
  Stream<OfficialAnswer?> watchAnswer(String questionId) =>
      QaModel.answerRef(_db, questionId).snapshots().map(
        (s) => s.exists && s.data() != null
            ? QaModel.answerFromMap(questionId, s.data()!)
            : null,
      );

  void _validateBody(String body) {
    if (body.trim().isEmpty) {
      throw const AppException.validation('Write an answer first.');
    }
    if (body.trim().length > Limits.answerBodyMax) {
      throw const AppException.validation('The answer is too long.');
    }
  }

  @override
  Future<void> saveDraftAnswer(
    String questionId,
    String body,
    AppUser admin,
  ) => guard(() async {
    _validateBody(body);
    final ref = QaModel.answerRef(_db, questionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists &&
          AnswerStatus.fromWire(snap.data()!['status']) ==
              AnswerStatus.published) {
        throw const AppException.conflict(
          'This answer is already published. Unpublish it before saving a draft.',
        );
      }
      tx.set(ref, {
        'questionId': questionId,
        'adminUid': admin.uid,
        'adminName': admin.displayName,
        'body': body.trim(),
        'status': AnswerStatus.draft.wire,
        'publishedAt': null,
        'createdAt': snap.exists
            ? snap.data()!['createdAt']
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<void> publishAnswer(Question question, String body, AppUser admin) =>
      guard(() async {
        _validateBody(body);
        if (question.status == QuestionStatus.closed) {
          throw const AppException.conflict(
            'Reopen this question before answering it.',
          );
        }
        final ref = QaModel.answerRef(_db, question.id);
        await _db.runTransaction((tx) async {
          final qSnap = await tx.get(_col.doc(question.id));
          final aSnap = await tx.get(ref);
          if (!qSnap.exists) throw const AppException.notFound();
          tx.set(ref, {
            'questionId': question.id,
            'adminUid': admin.uid,
            'adminName': admin.displayName,
            'body': body.trim(),
            'status': AnswerStatus.published.wire,
            'publishedAt': FieldValue.serverTimestamp(),
            'createdAt': aSnap.exists
                ? aSnap.data()!['createdAt']
                : FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          // Question status and answer publication change together; rules
          // verify the answer via getAfter().
          tx.update(_col.doc(question.id), {
            'status': QuestionStatus.answered.wire,
            'answeredAt': FieldValue.serverTimestamp(),
            'answeredByName': admin.displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          ActivityLog.addToTransaction(
            _db,
            tx,
            admin,
            action: 'answer.published',
            entityType: 'question',
            entityId: question.id,
            summary: 'Answered “${question.title}”',
          );
        });
      });

  @override
  Future<void> unpublishAnswer(Question question, AppUser admin) =>
      guard(() async {
        final batch = _db.batch();
        batch.update(QaModel.answerRef(_db, question.id), {
          'status': AnswerStatus.draft.wire,
          'publishedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batch.update(_col.doc(question.id), {
          'status': QuestionStatus.open.wire,
          'answeredAt': null,
          'answeredByName': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ActivityLog.addToBatch(
          _db,
          batch,
          admin,
          action: 'answer.unpublished',
          entityType: 'question',
          entityId: question.id,
          summary: 'Withdrew answer to “${question.title}”',
        );
        await batch.commit();
      });

  @override
  Future<void> setQuestionStatus(
    Question question,
    QuestionStatus next,
    AppUser admin,
  ) => guard(() async {
    if (next == QuestionStatus.answered) {
      throw const AppException.validation(
        'Publish an answer to mark a question answered.',
      );
    }
    final batch = _db.batch();
    batch.update(_col.doc(question.id), {
      'status': next.wire,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ActivityLog.addToBatch(
      _db,
      batch,
      admin,
      action: 'question.${next.wire}',
      entityType: 'question',
      entityId: question.id,
      summary:
          '${next == QuestionStatus.closed ? 'Closed' : 'Reopened'} “${question.title}”',
    );
    await batch.commit();
  });
}

class FirestoreAdminDashboardRepository implements AdminDashboardRepository {
  FirestoreAdminDashboardRepository(this._db);

  final FirebaseFirestore _db;

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  @override
  Future<DashboardMetrics> metrics() => guard(() async {
    Query<Map<String, dynamic>> byStatus(String col, String status) =>
        _db.collection(col).where('status', isEqualTo: status);
    final published = ContentStatus.published.wire;
    final draft = ContentStatus.draft.wire;
    final results = await Future.wait([
      _count(byStatus(SermonModel.collection, published)),
      _count(
        _db
            .collection(RecordingModel.collection)
            .where(
              'status',
              whereIn: [
                RecordingStatus.submitted.wire,
                RecordingStatus.underReview.wire,
              ],
            ),
      ),
      _count(byStatus(BookModel.collection, published)),
      _count(byStatus(ArticleModel.collection, published)),
      _count(byStatus(QaModel.questions, QuestionStatus.open.wire)),
      _count(byStatus(SermonModel.collection, draft)),
      _count(byStatus(BookModel.collection, draft)),
      _count(byStatus(ArticleModel.collection, draft)),
    ]);
    return DashboardMetrics(
      publishedSermons: results[0],
      pendingReviews: results[1],
      publishedBooks: results[2],
      publishedArticles: results[3],
      unansweredQuestions: results[4],
      draftItems: results[5] + results[6] + results[7],
    );
  });

  @override
  Stream<List<ActivityEntry>> recentActivity({int limit = 10}) => _db
      .collection(ActivityLog.collection)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ActivityLog.fromMap(d.id, d.data())).toList(),
      );
}
