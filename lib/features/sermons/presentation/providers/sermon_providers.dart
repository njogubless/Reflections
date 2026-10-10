import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/pagination/paged.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/listening_history_store.dart';
import '../../data/repositories/firestore_sermon_repository.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/repositories/sermon_repository.dart';

final sermonRepositoryProvider = Provider<SermonRepository>(
  (ref) => FirestoreSermonRepository(ref.watch(firestoreProvider)),
);

final listeningHistoryStoreProvider = Provider<ListeningHistoryStore>(
  (ref) => ListeningHistoryStore(SharedPreferencesAsync()),
);

final recentSermonsProvider = StreamProvider.autoDispose<List<Sermon>>(
  (ref) => ref.watch(sermonRepositoryProvider).watchRecent(),
);

final featuredSermonProvider = StreamProvider.autoDispose<Sermon?>(
  (ref) => ref.watch(sermonRepositoryProvider).watchFeatured(),
);

final sermonDetailProvider = FutureProvider.autoDispose.family<Sermon, String>(
  (ref, id) => ref.watch(sermonRepositoryProvider).getPublished(id),
);

final relatedSermonsProvider = FutureProvider.autoDispose
    .family<List<Sermon>, String>((ref, id) async {
      final sermon = await ref.watch(sermonDetailProvider(id).future);
      return ref.watch(sermonRepositoryProvider).relatedTo(sermon);
    });

final continueListeningProvider =
    FutureProvider.autoDispose<ListeningProgress?>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      final p = await ref.watch(listeningHistoryStoreProvider).last(user.uid);
      return (p == null || p.isFinished) ? null : p;
    });

final sermonLibraryQueryProvider =
    NotifierProvider.autoDispose<SermonQueryNotifier, SermonQuery>(
      SermonQueryNotifier.new,
    );

class SermonQueryNotifier extends Notifier<SermonQuery> {
  @override
  SermonQuery build() => const SermonQuery();

  void setCategory(String? category) =>
      state = SermonQuery(category: category, search: state.search);

  void setSearch(String? search) {
    final s = search?.trim();
    // Search and category are mutually exclusive to keep queries index-backed.
    state = SermonQuery(search: (s == null || s.isEmpty) ? null : s);
  }
}

final sermonLibraryProvider = NotifierProvider.autoDispose
    .family<SermonLibraryNotifier, PagedState<Sermon>, SermonQuery>(
      SermonLibraryNotifier.new,
    );

class SermonLibraryNotifier extends PagedNotifier<Sermon> {
  SermonLibraryNotifier(this.query);

  final SermonQuery query;

  @override
  Future<PageResult<Sermon>> fetchPage(Object? cursor, int limit) => ref
      .read(sermonRepositoryProvider)
      .fetchPublished(query, cursor: cursor, limit: limit);
}
