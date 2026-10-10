import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/media_storage.dart';
import '../../domain/entities/recording_status.dart';
import '../../domain/entities/recording_submission.dart';
import '../../domain/repositories/recording_repositories.dart';
import '../models/recording_model.dart';

class FirestoreSubmissionRepository implements SubmissionRepository {
  FirestoreSubmissionRepository(this._db, this._media);

  final FirebaseFirestore _db;
  final MediaStorage _media;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(RecordingModel.collection);

  @override
  Stream<List<RecordingSubmission>> watchMine(
    String ownerUid, {
    int limit = 50,
  }) => _col
      .where('ownerUid', isEqualTo: ownerUid)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => RecordingModel.fromMap(d.id, d.data())).toList(),
      );

  @override
  Stream<RecordingSubmission?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? RecordingModel.fromMap(s.id, s.data()!)
            : null,
      );

  @override
  UploadHandle uploadAudio({
    required String ownerUid,
    required String recordingId,
    required File file,
  }) => _media.uploadFile(
    storagePath: RecordingSubmission.storagePathFor(ownerUid, recordingId),
    file: file,
    contentType: 'audio/mp4',
  );

  void _validate(SermonMetadata m, Duration? duration, int? sizeBytes) {
    if (m.title.trim().isEmpty) {
      throw const AppException.validation('A title is required.');
    }
    if (duration != null) {
      if (duration <= Duration.zero) {
        throw const AppException.validation('The recording is empty.');
      }
      if (duration > RecordingLimits.maxDuration) {
        throw const AppException.validation(
          'Recordings must be 20 minutes or shorter.',
        );
      }
    }
    if (sizeBytes != null && sizeBytes > RecordingLimits.maxBytes) {
      throw const AppException.validation(
        'The recording file is too large to upload.',
      );
    }
  }

  @override
  Future<void> submitNew({
    required String recordingId,
    required String ownerUid,
    required String ownerName,
    required SermonMetadata metadata,
    required Duration duration,
    required int sizeBytes,
  }) => guard(() async {
    _validate(metadata, duration, sizeBytes);
    final ref = _col.doc(recordingId);
    // Retry after a lost response: the document may already exist.
    try {
      final existing = await ref.get();
      if (existing.exists) {
        final d = existing.data()!;
        if (d['ownerUid'] == ownerUid) return;
        throw const AppException.conflict(
          'This recording was already submitted.',
        );
      }
    } on FirebaseException catch (e) {
      // Rules deny reads of non-existent docs that aren't ours; proceed to
      // create, which the rules validate authoritatively.
      if (e.code != 'permission-denied') rethrow;
    }
    await ref.set({
      ...RecordingModel.metadataMap(metadata),
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'storagePath': RecordingSubmission.storagePathFor(ownerUid, recordingId),
      'durationSeconds': duration.inSeconds.clamp(
        1,
        RecordingLimits.maxDuration.inSeconds,
      ),
      'sizeBytes': sizeBytes,
      'status': RecordingStatus.submitted.wire,
      'revision': 1,
      'reviewFeedback': null,
      'reviewedBy': null,
      'reviewerName': null,
      'reviewedAt': null,
      'publishedSermonId': null,
      'submittedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> resubmit({
    required RecordingSubmission current,
    required SermonMetadata metadata,
    Duration? newDuration,
    int? newSizeBytes,
  }) => guard(() async {
    _validate(metadata, newDuration, newSizeBytes);
    final ref = _col.doc(current.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw const AppException.notFound();
      final status = RecordingStatus.fromWire(snap.data()!['status']);
      if (status == RecordingStatus.submitted) return; // already resubmitted
      if (!RecordingTransitions.canTransition(
        status,
        RecordingStatus.submitted,
        RecordingActor.owner,
      )) {
        throw const AppException.conflict(
          'This recording can no longer be edited. Refresh to see its latest status.',
        );
      }
      tx.update(ref, {
        ...RecordingModel.metadataMap(metadata),
        if (newDuration != null)
          'durationSeconds': newDuration.inSeconds.clamp(
            1,
            RecordingLimits.maxDuration.inSeconds,
          ),
        'sizeBytes': ?newSizeBytes,
        'status': RecordingStatus.submitted.wire,
        'revision': FieldValue.increment(1),
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  });
}
