import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/pagination/paged.dart';
import '../../../../core/utils/keywords.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../recording/data/models/recording_model.dart';
import '../../../recording/domain/entities/recording_status.dart';
import '../../../recording/domain/entities/recording_submission.dart';
import '../../../sermons/data/models/sermon_model.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../activity_log.dart';

/// Every review action runs in a transaction that re-reads the current
/// status, so concurrent reviewers or stale screens cannot apply an invalid
/// transition. Firestore rules enforce the same table server-side.
class FirestoreRecordingReviewRepository implements RecordingReviewRepository {
  FirestoreRecordingReviewRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(RecordingModel.collection);

  @override
  Future<PageResult<RecordingSubmission>> fetchQueue(
    Set<RecordingStatus> statuses, {
    Object? cursor,
    int limit = 20,
  }) => guard(() async {
    var q = _col
        .where('status', whereIn: statuses.map((s) => s.wire).toList())
        .orderBy('submittedAt');
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    q = q.limit(limit);
    final snap = await q.get();
    return PageResult(
      snap.docs.map((d) => RecordingModel.fromMap(d.id, d.data())).toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Stream<RecordingSubmission?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? RecordingModel.fromMap(s.id, s.data()!)
            : null,
      );

  Future<void> _transition(
    String id,
    RecordingStatus to,
    AppUser admin, {
    String? feedback,
  }) => guard(() async {
    if (!admin.isAdmin) throw const AppException.permission();
    if (RecordingTransitions.requiresFeedback(to) &&
        Validators.feedback(feedback) != null) {
      throw AppException.validation(Validators.feedback(feedback)!);
    }
    await _db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw const AppException.notFound();
      final current = RecordingModel.fromMap(snap.id, snap.data()!);
      if (current.status == to) return; // idempotent retry
      if (!RecordingTransitions.canTransition(
        current.status,
        to,
        RecordingActor.admin,
      )) {
        throw AppException.conflict(
          'This recording is now “${current.status.label}” and can’t be moved to “${to.label}”. Refresh to see the latest.',
        );
      }
      final isDecision = to != RecordingStatus.underReview;
      tx.update(ref, {
        'status': to.wire,
        'reviewedBy': admin.uid,
        'reviewerName': admin.displayName,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (isDecision)
          'reviewFeedback': feedback?.trim().isEmpty ?? true
              ? null
              : feedback!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ActivityLog.addToTransaction(
        _db,
        tx,
        admin,
        action: 'recording.${to.wire}',
        entityType: 'recording',
        entityId: id,
        summary: '${to.label}: “${current.title}” by ${current.ownerName}',
      );
    });
  });

  @override
  Future<void> startReview(String recordingId, AppUser admin) =>
      _transition(recordingId, RecordingStatus.underReview, admin);

  @override
  Future<void> decide(
    String recordingId,
    RecordingStatus decision,
    AppUser admin, {
    String? feedback,
  }) {
    const decisions = {
      RecordingStatus.approved,
      RecordingStatus.rejected,
      RecordingStatus.changesRequested,
    };
    if (!decisions.contains(decision)) {
      throw ArgumentError.value(decision, 'decision', 'Not a review decision');
    }
    return _transition(recordingId, decision, admin, feedback: feedback);
  }

  @override
  Future<String> publish(
    RecordingSubmission recording,
    AppUser admin, {
    required String category,
    String? scriptureQuote,
  }) => guard(() async {
    if (!admin.isAdmin) throw const AppException.permission();
    final sermonId = RecordingSubmission.sermonIdFor(recording.id);
    await _db.runTransaction((tx) async {
      final recRef = _col.doc(recording.id);
      final sermonRef = _db.collection(SermonModel.collection).doc(sermonId);
      final recSnap = await tx.get(recRef);
      final sermonSnap = await tx.get(sermonRef);
      if (!recSnap.exists) throw const AppException.notFound();
      final current = RecordingModel.fromMap(recSnap.id, recSnap.data()!);
      if (current.status == RecordingStatus.published && sermonSnap.exists) {
        return;
      }
      if (current.status != RecordingStatus.approved) {
        throw AppException.conflict(
          'Only approved recordings can be published (currently “${current.status.label}”).',
        );
      }
      // Deterministic sermon ID: a retried publish can never duplicate.
      if (!sermonSnap.exists) {
        final m = current.metadata;
        tx.set(sermonRef, {
          'title': m.title,
          'description': m.description,
          'speakerName': m.speakerName.isEmpty
              ? current.ownerName
              : m.speakerName,
          'scriptureReference': m.scriptureReference,
          'scriptureQuote': scriptureQuote?.trim().isEmpty ?? true
              ? null
              : scriptureQuote!.trim(),
          'category': category,
          'featured': false,
          'keywords': buildKeywords([
            m.title,
            m.speakerName,
            current.ownerName,
            m.scriptureReference,
            category,
          ]),
          'sourceType': SermonSource.userSubmission.wire,
          'status': ContentStatus.published.wire,
          'storagePath': current.storagePath,
          'coverStoragePath': null,
          'durationSeconds': current.durationSeconds,
          'audioSizeBytes': current.sizeBytes,
          'uploadedBy': admin.uid,
          'originRecordingId': current.id,
          'publishedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(recRef, {
        'status': RecordingStatus.published.wire,
        'publishedSermonId': sermonId,
        'reviewedBy': admin.uid,
        'reviewerName': admin.displayName,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ActivityLog.addToTransaction(
        _db,
        tx,
        admin,
        action: 'recording.published',
        entityType: 'sermon',
        entityId: sermonId,
        summary: 'Published community recording “${current.title}”',
      );
    });
    return sermonId;
  });
}
