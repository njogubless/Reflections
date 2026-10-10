import '../../../../core/pagination/paged.dart';
import '../entities/article.dart';

abstract class ArticleRepository {
  Future<PageResult<Article>> fetchPublished({
    String? category,
    Object? cursor,
    int limit = 20,
  });
  Stream<List<Article>> watchLatest({int limit = 3});
  Future<Article> getPublished(String id);
}
