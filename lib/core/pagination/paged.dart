import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';

/// One page from a repository. [cursor] is opaque to callers (the data layer
/// stores its last document snapshot there).
class PageResult<T> {
  const PageResult(this.items, {this.cursor, required this.hasMore});

  final List<T> items;
  final Object? cursor;
  final bool hasMore;
}

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<T> items;
  final Object? cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final AppException? error;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    Object? cursor,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    AppException? error,
    bool clearError = false,
  }) => PagedState(
    items: items ?? this.items,
    cursor: cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Base controller for bounded, cursor-paginated lists.
abstract class PagedNotifier<T> extends Notifier<PagedState<T>> {
  static const pageSize = 20;

  Future<PageResult<T>> fetchPage(Object? cursor, int limit);

  bool _inFlight = false;

  @override
  PagedState<T> build() {
    Future.microtask(refresh);
    return PagedState<T>();
  }

  Future<void> refresh() async {
    _inFlight = false;
    state = PagedState<T>();
    await _load(reset: true);
  }

  Future<void> loadMore() async {
    if (_inFlight || !state.hasMore || state.isLoading) return;
    await _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    _inFlight = true;
    if (!reset) state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await fetchPage(reset ? null : state.cursor, pageSize);
      if (!ref.mounted) return;
      state = PagedState<T>(
        items: reset ? page.items : [...state.items, ...page.items],
        cursor: page.cursor,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } catch (e, s) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: AppException.from(e, s),
      );
    } finally {
      _inFlight = false;
    }
  }
}
