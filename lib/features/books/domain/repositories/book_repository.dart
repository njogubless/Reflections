import '../../../../core/pagination/paged.dart';
import '../entities/book.dart';

abstract class BookRepository {
  Future<PageResult<Book>> fetchPublished({
    String? search,
    Object? cursor,
    int limit = 20,
  });
  Stream<List<Book>> watchLatest({int limit = 4});
  Future<Book> getPublished(String id);
}
