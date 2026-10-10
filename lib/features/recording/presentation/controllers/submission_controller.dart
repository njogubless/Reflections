import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/media_storage.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/recording_draft.dart';
import '../../domain/entities/recording_submission.dart';
import '../providers/recording_providers.dart';

enum SubmitPhase { idle, uploading, saving, done, failed }

class SubmitState {
  const SubmitState({this.phase = SubmitPhase.idle, this.progress, this.error});

  final SubmitPhase phase;
  final UploadProgress? progress;
  final AppException? error;

  bool get busy =>
      phase == SubmitPhase.uploading || phase == SubmitPhase.saving;
}

/// Uploads a local draft and creates (or resubmits) its review record.
/// Upload happens only on explicit submit. Retries overwrite the same storage
/// object and reuse the same document ID, so they never duplicate.
class SubmissionController extends Notifier<SubmitState> {
  SubmissionController(this.draftId);

  final String draftId;
  UploadHandle? _upload;
  StreamSubscription<UploadProgress>? _progressSub;
  bool _uploaded = false;
  bool _uploading = false; // readable during dispose, unlike `state`

  @override
  SubmitState build() {
    ref.onDispose(() {
      _progressSub?.cancel();
      // Navigating away mid-upload cancels it; the draft stays on-device.
      if (_uploading) _upload?.cancel();
    });
    return const SubmitState();
  }

  Future<void> saveMetadata(RecordingDraft draft, SermonMetadata metadata) =>
      ref
          .read(draftRepositoryProvider)
          .update(draft.copyWith(metadata: metadata));

  Future<bool> submit(RecordingDraft draft, SermonMetadata metadata) async {
    if (state.busy || state.phase == SubmitPhase.done) return false;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const SubmitState(
        phase: SubmitPhase.failed,
        error: AppException.permission(),
      );
      return false;
    }
    final repo = ref.read(submissionRepositoryProvider);
    try {
      if (metadata.title.trim().isEmpty) {
        throw const AppException.validation('Add a title before submitting.');
      }
      if (draft.duration > RecordingLimits.maxDuration) {
        throw const AppException.validation(
          'Recordings must be 20 minutes or shorter.',
        );
      }
      await saveMetadata(draft, metadata);

      final file = File(draft.filePath);
      if (!await file.exists()) {
        throw const AppException.notFound(
          'The recording file is missing from this device.',
        );
      }
      final size = await file.length();
      if (size > RecordingLimits.maxBytes) {
        throw const AppException.validation(
          'The recording file is too large to upload.',
        );
      }

      if (!_uploaded) {
        state = const SubmitState(phase: SubmitPhase.uploading);
        final handle = repo.uploadAudio(
          ownerUid: user.uid,
          recordingId: draft.recordingId,
          file: file,
        );
        _upload = handle;
        _uploading = true;
        await _progressSub?.cancel();
        _progressSub = handle.progress.listen((p) {
          if (ref.mounted && state.phase == SubmitPhase.uploading) {
            state = SubmitState(phase: SubmitPhase.uploading, progress: p);
          }
        });
        try {
          await handle.done;
        } finally {
          _uploading = false;
        }
        _uploaded = true;
      }
      if (!ref.mounted) return false;
      state = SubmitState(phase: SubmitPhase.saving, progress: state.progress);

      if (draft.resubmissionOf != null) {
        final current = await repo.watch(draft.resubmissionOf!).first;
        if (current == null) throw const AppException.notFound();
        await repo.resubmit(
          current: current,
          metadata: metadata,
          newDuration: draft.duration,
          newSizeBytes: size,
        );
      } else {
        await repo.submitNew(
          recordingId: draft.recordingId,
          ownerUid: user.uid,
          ownerName: user.displayName,
          metadata: metadata,
          duration: draft.duration,
          sizeBytes: size,
        );
      }
      await ref.read(draftRepositoryProvider).delete(draft.id);
      if (!ref.mounted) return true;
      ref.invalidate(draftsProvider);
      state = const SubmitState(phase: SubmitPhase.done);
      return true;
    } catch (e, s) {
      if (!ref.mounted) return false;
      state = SubmitState(
        phase: SubmitPhase.failed,
        error: AppException.from(e, s),
      );
      return false;
    }
  }

  Future<void> cancelUpload() async {
    await _upload?.cancel();
    if (ref.mounted) {
      state = const SubmitState(
        phase: SubmitPhase.failed,
        error: AppException(
          AppErrorKind.unexpected,
          'Upload cancelled. Your draft is saved.',
        ),
      );
    }
  }
}

final submissionControllerProvider = NotifierProvider.autoDispose
    .family<SubmissionController, SubmitState, String>(
      SubmissionController.new,
    );

/// Metadata-only resubmission for `changes_requested` recordings.
class ResubmitController extends Notifier<AsyncValue<void>> {
  ResubmitController(this.recordingId);

  final String recordingId;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> resubmit(
    RecordingSubmission current,
    SermonMetadata metadata,
  ) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ref
          .read(submissionRepositoryProvider)
          .resubmit(current: current, metadata: metadata);
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (ref.mounted) state = AsyncError(AppException.from(e, s), s);
      return false;
    }
  }
}

final resubmitControllerProvider = NotifierProvider.autoDispose
    .family<ResubmitController, AsyncValue<void>, String>(
      ResubmitController.new,
    );
