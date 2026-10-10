import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/pagination/paged.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/book_data.dart';
import '../domain/entities/book.dart';
import '../domain/repositories/book_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => FirestoreBookRepository(ref.watch(firestoreProvider)),
);

final latestBooksProvider = StreamProvider.autoDispose<List<Book>>(
  (ref) => ref.watch(bookRepositoryProvider).watchLatest(),
);

final bookDetailProvider = FutureProvider.autoDispose.family<Book, String>(
  (ref, id) => ref.watch(bookRepositoryProvider).getPublished(id),
);

class BookLibrary extends PagedNotifier<Book> {
  BookLibrary(this.search);
  final String? search;

  @override
  Future<PageResult<Book>> fetchPage(Object? cursor, int limit) => ref
      .read(bookRepositoryProvider)
      .fetchPublished(search: search, cursor: cursor, limit: limit);
}

final bookLibraryProvider = NotifierProvider.autoDispose
    .family<BookLibrary, PagedState<Book>, String?>(BookLibrary.new);

/// Last page read, stored on-device per user.
class ReadingProgressStore {
  ReadingProgressStore(this._prefs, this._uid);

  final SharedPreferencesAsync _prefs;
  final String? _uid;

  String _key(String bookId) => 'reading.page.${_uid ?? '_'}.$bookId';

  Future<int> lastPage(String bookId) async =>
      await _prefs.getInt(_key(bookId)) ?? 1;

  Future<void> save(String bookId, int page) =>
      _prefs.setInt(_key(bookId), page);
}

final readingProgressStoreProvider = Provider<ReadingProgressStore>(
  (ref) => ReadingProgressStore(
    SharedPreferencesAsync(),
    ref.watch(currentUserProvider)?.uid,
  ),
);

final lastPageProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, bookId) => ref.watch(readingProgressStoreProvider).lastPage(bookId),
);
