import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/paged_list.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../articles/domain/entities/article.dart';
import '../../../articles/presentation/article_pages.dart';
import '../../../books/domain/entities/book.dart';
import '../../../books/presentation/book_pages.dart';
import '../../../books/presentation/book_providers.dart';
import '../widgets/header_actions.dart';

/// "Read" tab: books library and article feed.
class ReadPage extends StatelessWidget {
  const ReadPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.page,
        title: const BrandTitle(section: 'Read'),
        actions: const [HeaderActions()],
        bottom: TabBar(
          indicatorColor: AppColors.gold,
          labelColor: AppColors.primaryInk,
          unselectedLabelColor: AppColors.inkMuted,
          labelStyle: context.text.labelLarge,
          tabs: const [
            Tab(text: 'Articles'),
            Tab(text: 'Books'),
          ],
        ),
      ),
      body: const TabBarView(children: [_ArticlesTab(), _BooksTab()]),
    ),
  );
}

class _ArticlesTab extends ConsumerStatefulWidget {
  const _ArticlesTab();

  @override
  ConsumerState<_ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends ConsumerState<_ArticlesTab> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(articleFeedProvider(_category));
    final notifier = ref.read(articleFeedProvider(_category).notifier);
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: 10,
                ),
                children: [
                  for (final c in [null, ...articleCategories])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text((c ?? 'All').toUpperCase()),
                        selected: _category == c,
                        showCheckmark: false,
                        labelStyle: context.text.labelSmall?.copyWith(
                          color: _category == c ? Colors.white : AppColors.ink,
                        ),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PagedSliverList<Article>(
            state: feed,
            onLoadMore: notifier.loadMore,
            onRetry: notifier.refresh,
            itemBuilder: (_, a) => ArticleCard(article: a),
            empty: const EmptyView(
              icon: Icons.article_outlined,
              title: 'No articles yet',
              message: 'Reflections and teaching articles will appear here.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BooksTab extends ConsumerStatefulWidget {
  const _BooksTab();

  @override
  ConsumerState<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends ConsumerState<_BooksTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _query;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookLibraryProvider(_query));
    final notifier = ref.read(bookLibraryProvider(_query).notifier);
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search title or author',
                  prefixIcon: Icon(Icons.search, color: AppColors.goldDeep),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    setState(() => _query = v.trim().isEmpty ? null : v.trim());
                  });
                },
              ),
            ),
          ),
          PagedSliverList<Book>(
            state: books,
            onLoadMore: notifier.loadMore,
            onRetry: notifier.refresh,
            itemBuilder: (_, b) => BookCard(book: b),
            empty: _query != null
                ? EmptyView(
                    icon: Icons.search_off,
                    title: 'No books found',
                    message:
                        'Nothing matched “$_query”. Try a single word from the title or author.',
                  )
                : const EmptyView(
                    icon: Icons.menu_book_outlined,
                    title: 'No books yet',
                    message:
                        'Books published by the ministry will appear here.',
                  ),
          ),
        ],
      ),
    );
  }
}
