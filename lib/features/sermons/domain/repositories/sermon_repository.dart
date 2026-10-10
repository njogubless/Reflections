import '../../../../core/pagination/paged.dart';
import '../entities/sermon.dart';

class SermonQuery {
  const SermonQuery({this.category, this.search});

  final String? category;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is SermonQuery &&
      other.category == category &&
      other.search == search;

  @override
  int get hashCode => Object.hash(category, search);
}

/// Read access to the *published* sermon catalogue only.
abstract class SermonRepository {
  Future<PageResult<Sermon>> fetchPublished(
    SermonQuery query, {
    Object? cursor,
    int limit = 20,
  });

  Stream<List<Sermon>> watchRecent({int limit = 6});

  Stream<Sermon?> watchFeatured();

  Future<Sermon> getPublished(String id);

  /// Other published sermons by the same speaker (bounded).
  Future<List<Sermon>> relatedTo(Sermon sermon, {int limit = 3});

  Future<int> countPublished();
}
