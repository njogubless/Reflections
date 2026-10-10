import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../firebase/firebase_providers.dart';

enum UploadPhase { running, paused, success, failed, canceled }

class UploadProgress {
  const UploadProgress({
    required this.phase,
    required this.bytesTransferred,
    required this.totalBytes,
    this.error,
  });

  final UploadPhase phase;
  final int bytesTransferred;
  final int totalBytes;
  final AppException? error;

  double get fraction => totalBytes <= 0
      ? 0
      : (bytesTransferred / totalBytes).clamp(0, 1).toDouble();
}

/// A running upload: observe [progress], await [done], or [cancel].
class UploadHandle {
  UploadHandle(this.progress, this.done, this._cancel);

  final Stream<UploadProgress> progress;

  /// Completes when the object is stored; throws [AppException] on failure.
  final Future<void> done;
  final Future<void> Function() _cancel;

  Future<void> cancel() => _cancel();
}

/// Storage abstraction. Content records store *paths*; download URLs are
/// resolved on demand so that unpublishing (with token rotation) revokes access.
abstract class MediaStorage {
  UploadHandle uploadFile({
    required String storagePath,
    required File file,
    required String contentType,
  });

  UploadHandle uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
  });

  Future<String> downloadUrl(String storagePath);

  Future<void> delete(String storagePath);
}

class FirebaseMediaStorage implements MediaStorage {
  FirebaseMediaStorage(this._storage);

  final FirebaseStorage _storage;

  @override
  UploadHandle uploadFile({
    required String storagePath,
    required File file,
    required String contentType,
  }) => _wrap(
    _storage
        .ref(storagePath)
        .putFile(file, SettableMetadata(contentType: contentType)),
  );

  @override
  UploadHandle uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
  }) => _wrap(
    _storage
        .ref(storagePath)
        .putData(bytes, SettableMetadata(contentType: contentType)),
  );

  UploadHandle _wrap(UploadTask task) {
    final controller = StreamController<UploadProgress>.broadcast();
    final sub = task.snapshotEvents.listen(
      (s) {
        final phase = switch (s.state) {
          TaskState.running => UploadPhase.running,
          TaskState.paused => UploadPhase.paused,
          TaskState.success => UploadPhase.success,
          TaskState.canceled => UploadPhase.canceled,
          TaskState.error => UploadPhase.failed,
        };
        controller.add(
          UploadProgress(
            phase: phase,
            bytesTransferred: s.bytesTransferred,
            totalBytes: s.totalBytes,
          ),
        );
      },
      onError: (Object e, StackTrace st) {
        controller.add(
          UploadProgress(
            phase: UploadPhase.failed,
            bytesTransferred: 0,
            totalBytes: 0,
            error: AppException.from(e, st),
          ),
        );
      },
    );
    final done = task
        .then((_) {})
        .catchError((Object e, StackTrace st) {
          throw AppException.from(e, st);
        })
        .whenComplete(() async {
          await sub.cancel();
          await controller.close();
        });
    return UploadHandle(controller.stream, done, () async {
      await task.cancel();
    });
  }

  @override
  Future<String> downloadUrl(String storagePath) =>
      guard(() => _storage.ref(storagePath).getDownloadURL());

  @override
  Future<void> delete(String storagePath) => guard(() async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  });
}

final mediaStorageProvider = Provider<MediaStorage>(
  (ref) => FirebaseMediaStorage(ref.watch(firebaseStorageProvider)),
);

/// Resolves a storage path to a download URL. Kept alive briefly so lists
/// don't refetch while scrolling.
final mediaUrlProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  path,
) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(mediaStorageProvider).downloadUrl(path);
});
