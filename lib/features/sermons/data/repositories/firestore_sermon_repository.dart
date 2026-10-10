import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/pagination/paged.dart';
import '../../../../core/utils/keywords.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/repositories/sermon_repository.dart';
import '../models/sermon_model.dart';

class FirestoreSermonRepository implements SermonRepository {
  FirestoreSermonRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(SermonModel.collection);

  /// Every public query must constrain `status == published`; the security
  /// rules reject anything broader for non-admins.
  Query<Map<String, dynamic>> get _published =>
      _col.where('status', isEqualTo: ContentStatus.published.wire);

  @override
  Future<PageResult<Sermon>> fetchPublished(
    SermonQuery query, {
    Object? cursor,
    int limit = 20,
  }) => guard(() async {
    var q = _published;
    if (query.category != null) {
      q = q.where('category', isEqualTo: query.category);
    }
    final token = query.search == null ? null : searchToken(query.search!);
    if (token != null) q = q.where('keywords', arrayContains: token);
    q = q.orderBy('publishedAt', descending: true);
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
  Stream<List<Sermon>> watchRecent({int limit = 6}) => _published
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => SermonModel.fromMap(d.id, d.data())).toList(),
      );

  @override
  Stream<Sermon?> watchFeatured() => _published
      .where('featured', isEqualTo: true)
      .orderBy('publishedAt', descending: true)
      .limit(1)
      .snapshots()
      .map(
        (s) => s.docs.isEmpty
            ? null
            : SermonModel.fromMap(s.docs.first.id, s.docs.first.data()),
      );

  @override
  Future<Sermon> getPublished(String id) => guard(() async {
    final snap = await _col.doc(id).get().catchError(_hiddenAsNotFound);
    final data = snap.data();
    if (!snap.exists || data == null) throw const AppException.notFound();
    final sermon = SermonModel.fromMap(snap.id, data);
    // Admins can read drafts; never surface them through the user path.
    if (!sermon.status.isPublic) throw const AppException.notFound();
    return sermon;
  });

  @override
  Future<List<Sermon>> relatedTo(Sermon sermon, {int limit = 3}) =>
      guard(() async {
        if (sermon.speakerName.isEmpty) return const [];
        final snap = await _published
            .where('speakerName', isEqualTo: sermon.speakerName)
            .orderBy('publishedAt', descending: true)
            .limit(limit + 1)
            .get();
        return snap.docs
            .where((d) => d.id != sermon.id)
            .take(limit)
            .map((d) => SermonModel.fromMap(d.id, d.data()))
            .toList();
      });

  @override
  Future<int> countPublished() => guard(() async {
    final agg = await _published.count().get();
    return agg.count ?? 0;
  });
}

/// Rules deny non-admin reads of missing or unpublished documents; present
/// that as "not found" rather than a permission problem.
Never _hiddenAsNotFound(Object e) {
  if (e is FirebaseException && e.code == 'permission-denied') {
    throw const AppException.notFound();
  }
  throw e;
}
