import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../pagination/paged.dart';
import 'state_views.dart';

/// Lazily built list for a [PagedState]; requests the next page near the end.
class PagedSliverList<T> extends StatelessWidget {
  const PagedSliverList({
    super.key,
    required this.state,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    required this.empty,
    this.separator = AppSpacing.sm,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  final PagedState<T> state;
  final Widget Function(BuildContext, T) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Widget empty;
  final double separator;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingView(),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(error: state.error!, onRetry: onRetry),
      );
    }
    if (state.items.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false, child: empty);
    }
    final count = state.items.length + 1;
    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: count,
        itemBuilder: (context, i) {
          if (i == state.items.length) return _footer();
          if (state.hasMore && i >= state.items.length - 4) {
            WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
          }
          return Padding(
            padding: EdgeInsets.only(bottom: separator),
            child: itemBuilder(context, state.items[i]),
          );
        },
      ),
    );
  }

  Widget _footer() {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LoadingView(),
      );
    }
    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            InlineError(state.error!.message),
            TextButton(onPressed: onLoadMore, child: const Text('Load more')),
          ],
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}
