import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/media/media_storage.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/audio_recorder_service.dart';
import '../../data/datasources/local_draft_repository.dart';
import '../../data/repositories/firestore_submission_repository.dart';
import '../../domain/entities/recording_draft.dart';
import '../../domain/entities/recording_submission.dart';
import '../../domain/repositories/recording_repositories.dart';

/// A new recorder per studio session; disposed with the session.
final audioRecorderServiceProvider = Provider.autoDispose<AudioRecorderService>(
  (ref) {
    final service = RecordPackageService();
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Drafts are namespaced per user so shared devices don't mix them.
final draftRepositoryProvider = Provider<DraftRepository>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid ?? '_anon';
  return LocalDraftRepository(
    getApplicationDocumentsDirectory().then(
      (d) => Directory('${d.path}/recording_drafts/$uid'),
    ),
  );
});

final submissionRepositoryProvider = Provider<SubmissionRepository>(
  (ref) => FirestoreSubmissionRepository(
    ref.watch(firestoreProvider),
    ref.watch(mediaStorageProvider),
  ),
);

final draftsProvider = FutureProvider.autoDispose<List<RecordingDraft>>(
  (ref) => ref.watch(draftRepositoryProvider).list(),
);

final draftProvider = FutureProvider.autoDispose
    .family<RecordingDraft?, String>(
      (ref, id) => ref.watch(draftRepositoryProvider).get(id),
    );

final mySubmissionsProvider =
    StreamProvider.autoDispose<List<RecordingSubmission>>((ref) {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const Stream.empty();
      return ref.watch(submissionRepositoryProvider).watchMine(user.uid);
    });

final submissionProvider = StreamProvider.autoDispose
    .family<RecordingSubmission?, String>(
      (ref, id) => ref.watch(submissionRepositoryProvider).watch(id),
    );
