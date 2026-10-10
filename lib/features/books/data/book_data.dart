import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/domain/content_status.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/pagination/paged.dart';
import '../../../core/utils/firestore_utils.dart';
import '../../../core/utils/keywords.dart';
import '../domain/entities/book.dart';
import '../domain/repositories/book_repository.dart';

abstract final class BookModel {
  static const collection = 'books';

  static Book fromMap(String id, Map<String, dynamic> d) => Book(
    id: id,
    title: readString(d, 'title'),
    author: readString(d, 'author'),
    description: readString(d, 'description'),
    category: readString(d, 'category'),
    status: ContentStatus.fromWire(d['status']),
    coverStoragePath: readOptionalString(d, 'coverStoragePath'),
    fileStoragePath: readOptionalString(d, 'fileStoragePath'),
    fileFormat: BookFormat.fromWire(d['fileFormat']),
    fileSizeBytes: readInt(d, 'fileSizeBytes'),
    uploadedBy: readOptionalString(d, 'uploadedBy'),
    featured: d['featured'] == true,
    publishedAt: readDate(d['publishedAt']),
    createdAt: readDate(d['createdAt']),
    updatedAt: readDate(d['updatedAt']),
  );

  static Map<String, dynamic> metadataMap(Book b) => {
    'title': b.title.trim(),
    'author': b.author.trim(),
    'description': b.description.trim(),
    'category': b.category.trim(),
    'featured': b.featured,
    'keywords': buildKeywords([b.title, b.author, b.category]),
  };
}

abstract final class BookPaths {
  static String document(String id) => 'books/$id/document';
  static String cover(String id) => 'books/$id/cover';
}

class FirestoreBookRepository implements BookRepository {
  FirestoreBookRepository(this._db);

  final FirebaseFirestore _db;

  Query<Map<String, dynamic>> get _published => _db
      .collection(BookModel.collection)
      .where('status', isEqualTo: ContentStatus.published.wire);

  @override
  Future<PageResult<Book>> fetchPublished({
    String? search,
    Object? cursor,
    int limit = 20,
  }) => guard(() async {
    var q = _published;
    final token = search == null ? null : searchToken(search);
    if (token != null) q = q.where('keywords', arrayContains: token);
    q = q.orderBy('publishedAt', descending: true);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    q = q.limit(limit);
    final snap = await q.get();
    return PageResult(
      snap.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Stream<List<Book>> watchLatest({int limit = 4}) => _published
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => BookModel.fromMap(d.id, d.data())).toList(),
      );

  @override
  Future<Book> getPublished(String id) => guard(() async {
    final snap = await _db
        .collection(BookModel.collection)
        .doc(id)
        .get()
        .catchError(_hiddenAsNotFound);
    if (!snap.exists) throw const AppException.notFound();
    final book = BookModel.fromMap(snap.id, snap.data()!);
    if (!book.status.isPublic) throw const AppException.notFound();
    return book;
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
