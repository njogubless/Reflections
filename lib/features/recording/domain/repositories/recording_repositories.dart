import 'dart:io';

import '../../../../core/media/media_storage.dart';
import '../entities/recording_draft.dart';
import '../entities/recording_submission.dart';

/// On-device drafts (completed but unsubmitted recordings).
abstract class DraftRepository {
  /// A fresh file path for a new recording session.
  Future<String> newRecordingPath(String draftId);

  Future<RecordingDraft> saveNew({
    required String id,
    required String filePath,
    required Duration duration,
    String? resubmissionOf,
  });

  Future<void> update(RecordingDraft draft);

  Future<List<RecordingDraft>> list();

  Future<RecordingDraft?> get(String id);

  /// Deletes the draft and its audio file.
  Future<void> delete(String id);
}

/// The user's own submissions in Firestore/Storage.
abstract class SubmissionRepository {
  Stream<List<RecordingSubmission>> watchMine(
    String ownerUid, {
    int limit = 50,
  });

  Stream<RecordingSubmission?> watch(String id);

  UploadHandle uploadAudio({
    required String ownerUid,
    required String recordingId,
    required File file,
  });

  /// Creates the submission record. Idempotent: if the record already exists
  /// in `submitted` state for this owner, it is treated as success.
  Future<void> submitNew({
    required String recordingId,
    required String ownerUid,
    required String ownerName,
    required SermonMetadata metadata,
    required Duration duration,
    required int sizeBytes,
  });

  /// `changes_requested -> submitted`, optionally with replaced audio.
  Future<void> resubmit({
    required RecordingSubmission current,
    required SermonMetadata metadata,
    Duration? newDuration,
    int? newSizeBytes,
  });
}
