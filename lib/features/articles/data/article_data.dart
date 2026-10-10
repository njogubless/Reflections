import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/domain/content_status.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/pagination/paged.dart';
import '../../../core/utils/firestore_utils.dart';
import '../../../core/utils/keywords.dart';
import '../domain/entities/article.dart';
import '../domain/repositories/article_repository.dart';

abstract final class ArticleCategories {
  static const all = [
    'Devotional',
    'Theology',
    'Scripture study',
    'Prayer',
    'Church life',
    'Testimony',
  ];
}

abstract final class ArticleModel {
  static const collection = 'articles';

  static Article fromMap(String id, Map<String, dynamic> d) => Article(
    id: id,
    title: readString(d, 'title'),
    summary: readString(d, 'summary'),
    blocks: (d['blocks'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ArticleBlock.fromMap(m.cast<String, dynamic>()))
        .toList(),
    category: readString(d, 'category'),
    status: ContentStatus.fromWire(d['status']),
    authorId: readOptionalString(d, 'authorId'),
    authorName: readString(d, 'authorName'),
    coverStoragePath: readOptionalString(d, 'coverStoragePath'),
    tags: readStringList(d, 'tags'),
    readMinutes: readInt(d, 'readMinutes'),
    publishedAt: readDate(d['publishedAt']),
    createdAt: readDate(d['createdAt']),
    updatedAt: readDate(d['updatedAt']),
  );

  static Map<String, dynamic> contentMap(Article a) => {
    'title': a.title.trim(),
    'summary': a.summary.trim(),
    'blocks': a.blocks.map((b) => b.toMap()).toList(),
    'category': a.category,
    'tags': a.tags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList(),
    'readMinutes': ArticleBodyCodec.readMinutes(a.blocks),
    'keywords': buildKeywords([a.title, a.category, ...a.tags]),
  };
}

abstract final class ArticlePaths {
  static String cover(String id) => 'articles/$id/cover';
}

class FirestoreArticleRepository implements ArticleRepository {
  FirestoreArticleRepository(this._db);

  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> get _published => _db
      .collection(ArticleModel.collection)
      .where('status', isEqualTo: ContentStatus.published.wire);

  @override
  Future<PageResult<Article>> fetchPublished({
    String? category,
    Object? cursor,
    int limit = 20,
  }) => guard(() async {
    var q = _published;
    if (category != null) q = q.where('category', isEqualTo: category);
    q = q.orderBy('publishedAt', descending: true);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    q = q.limit(limit);
    final snap = await q.get();
    return PageResult(
      snap.docs.map((d) => ArticleModel.fromMap(d.id, d.data())).toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Stream<List<Article>> watchLatest({int limit = 3}) => _published
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ArticleModel.fromMap(d.id, d.data())).toList(),
      );

  @override
  Future<Article> getPublished(String id) => guard(() async {
    final snap = await _db
        .collection(ArticleModel.collection)
        .doc(id)
        .get()
        .catchError(_hiddenAsNotFound);
    if (!snap.exists) throw const AppException.notFound();
    final article = ArticleModel.fromMap(snap.id, snap.data()!);
    if (!article.status.isPublic) throw const AppException.notFound();
    return article;
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
