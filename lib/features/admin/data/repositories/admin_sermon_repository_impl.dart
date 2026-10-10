import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/media_storage.dart';
import '../../../../core/pagination/paged.dart';
import '../../../../core/utils/keywords.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../sermons/data/models/sermon_model.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../activity_log.dart';

class FirestoreAdminSermonRepository implements AdminSermonRepository {
  FirestoreAdminSermonRepository(this._db, this._media);

  final FirebaseFirestore _db;
  final MediaStorage _media;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(SermonModel.collection);

  @override
  String newId() => _col.doc().id;

  @override
  Future<PageResult<Sermon>> fetchAll({
    ContentStatus? status,
    Object? cursor,
    int limit = 20,
  }) => guard(() async {
    Query<Map<String, dynamic>> q = _col;
    if (status != null) q = q.where('status', isEqualTo: status.wire);
    q = q.orderBy('updatedAt', descending: true);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    q = q.limit(limit);
    final snap = await q.get();
    return PageResult(
      snap.docs.map((d) => SermonModel.fromMap(d.id, d.data())).toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Stream<Sermon?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? SermonModel.fromMap(s.id, s.data()!)
            : null,
      );

  Map<String, dynamic> _metadata(Sermon s) => {
    ...SermonModel.metadataMap(s),
    'keywords': buildKeywords([
      s.title,
      s.speakerName,
      s.scriptureReference,
      s.category,
    ]),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> saveMetadata(
    Sermon sermon,
    AppUser admin, {
    required bool isNew,
  }) => guard(() async {
    if (sermon.title.trim().isEmpty) {
      throw const AppException.validation('A title is required.');
    }
    final batch = _db.batch();
    final ref = _col.doc(sermon.id);
    if (isNew) {
      batch.set(ref, {
        ..._metadata(sermon),
        'sourceType': SermonSource.adminPublished.wire,
        'status': ContentStatus.draft.wire,
        'storagePath': null,
        'coverStoragePath': null,
        'durationSeconds': 0,
        'audioSizeBytes': 0,
        'uploadedBy': admin.uid,
        'originRecordingId': null,
        'publishedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ActivityLog.addToBatch(
        _db,
        batch,
        admin,
        action: 'sermon.created',
        entityType: 'sermon',
        entityId: sermon.id,
        summary: 'Created draft “${sermon.title.trim()}”',
      );
    } else {
      batch.update(ref, _metadata(sermon));
    }
    await batch.commit();
  });

  @override
  UploadHandle uploadAudio(String sermonId, File file, String contentType) =>
      _media.uploadFile(
        storagePath: SermonPaths.audio(sermonId),
        file: file,
        contentType: contentType,
      );

  @override
  Future<void> attachAudio(
    String sermonId, {
    required int durationSeconds,
    required int sizeBytes,
  }) => guard(
    () => _col.doc(sermonId).update({
      'storagePath': SermonPaths.audio(sermonId),
      'durationSeconds': durationSeconds,
      'audioSizeBytes': sizeBytes,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  UploadHandle uploadCover(String sermonId, File file, String contentType) =>
      _media.uploadFile(
        storagePath: SermonPaths.cover(sermonId),
        file: file,
        contentType: contentType,
      );

  @override
  Future<void> attachCover(String sermonId) => guard(
    () => _col.doc(sermonId).update({
      'coverStoragePath': SermonPaths.cover(sermonId),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> setStatus(
    Sermon sermon,
    ContentStatus next,
    AppUser admin,
  ) => guard(() async {
    if (!sermon.status.canTransitionTo(next)) {
      throw AppException.conflict(
        'A ${sermon.status.label.toLowerCase()} sermon cannot be moved to ${next.label.toLowerCase()}.',
      );
    }
    if (next == ContentStatus.published && !sermon.hasAudio) {
      throw const AppException.validation(
        'Upload the audio before publishing.',
      );
    }
    final batch = _db.batch();
    batch.update(_col.doc(sermon.id), {
      'status': next.wire,
      if (next == ContentStatus.published && sermon.publishedAt == null)
        'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ActivityLog.addToBatch(
      _db,
      batch,
      admin,
      action: 'sermon.${next.wire}',
      entityType: 'sermon',
      entityId: sermon.id,
      summary: '${next.label} “${sermon.title}”',
    );
    await batch.commit();
  });
}
