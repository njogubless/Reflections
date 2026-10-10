import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/paged_list.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../home/presentation/widgets/header_actions.dart';
import '../../domain/entities/sermon.dart';
import '../providers/sermon_providers.dart';
import '../widgets/sermon_widgets.dart';

final _publishedCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(sermonRepositoryProvider).countPublished(),
);

class SermonLibraryPage extends ConsumerStatefulWidget {
  const SermonLibraryPage({super.key});

  @override
  ConsumerState<SermonLibraryPage> createState() => _SermonLibraryPageState();
}

class _SermonLibraryPageState extends ConsumerState<SermonLibraryPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(sermonLibraryQueryProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(sermonLibraryQueryProvider);
    final library = ref.watch(sermonLibraryProvider(query));
    final libraryNotifier = ref.read(sermonLibraryProvider(query).notifier);
    final featured = ref.watch(featuredSermonProvider);
    final count = ref.watch(_publishedCountProvider);
    final browsing = query.search == null && query.category == null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredSermonProvider);
          ref.invalidate(_publishedCountProvider);
          await libraryNotifier.refresh();
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              titleSpacing: AppSpacing.page,
              title: BrandTitle(section: 'Sermons'),
              actions: [HeaderActions()],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  4,
                  AppSpacing.page,
                  0,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search sermon, preacher, scripture',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.goldDeep,
                    ),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              ref
                                  .read(sermonLibraryQueryProvider.notifier)
                                  .setSearch(null);
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
            ),
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
                    _CategoryChip(
                      label: 'All',
                      selected: query.category == null,
                      onTap: () => ref
                          .read(sermonLibraryQueryProvider.notifier)
                          .setCategory(null),
                    ),
                    for (final c in SermonCategories.all)
                      _CategoryChip(
                        label: c,
                        selected: query.category == c,
                        onTap: () {
                          _search.clear();
                          ref
                              .read(sermonLibraryQueryProvider.notifier)
                              .setCategory(c);
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (browsing)
              SliverToBoxAdapter(
                child: featured.maybeWhen(
                  data: (s) => s == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            AppSpacing.xs,
                            AppSpacing.page,
                            0,
                          ),
                          child: FeaturedSermonCard(sermon: s),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            if (browsing) const SliverToBoxAdapter(child: _ContributeBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      query.search != null
                          ? 'Results for “${query.search}”'
                          : (query.category ?? 'Published Sermons'),
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (browsing)
                      count.maybeWhen(
                        data: (n) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: AppRadii.pill,
                          ),
                          child: Text('$n', style: context.text.labelSmall),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    const Spacer(),
                    Text('Newest first', style: context.text.bodySmall),
                  ],
                ),
              ),
            ),
            PagedSliverList<Sermon>(
              state: library,
              onLoadMore: libraryNotifier.loadMore,
              onRetry: libraryNotifier.refresh,
              itemBuilder: (_, s) => SermonCard(sermon: s),
              empty: query.search != null
                  ? EmptyView(
                      icon: Icons.search_off,
                      title: 'No sermons found',
                      message:
                          'Nothing matched “${query.search}”. Try a single word such as a preacher’s surname or a book of the Bible.',
                    )
                  : const EmptyView(
                      icon: Icons.headphones_outlined,
                      title: 'No sermons yet',
                      message: 'Published sermons will appear here.',
                    ),
            ),
            const SliverToBoxAdapter(child: _FooterVerse()),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.xs),
    child: ChoiceChip(
      label: Text(label.toUpperCase()),
      selected: selected,
      showCheckmark: false,
      avatar: selected && label == 'All'
          ? const Icon(
              Icons.auto_awesome,
              size: 14,
              color: AppColors.goldContainer,
            )
          : null,
      labelStyle: context.text.labelSmall?.copyWith(
        color: selected ? Colors.white : AppColors.ink,
      ),
      onSelected: (_) => onTap(),
    ),
  );
}

class _ContributeBanner extends StatelessWidget {
  const _ContributeBanner();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.md,
      AppSpacing.page,
      0,
    ),
    child: AppCard(
      color: AppColors.surfaceLow,
      onTap: () => context.push(Routes.studio),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.goldContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_external_on,
              color: AppColors.goldDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Have a message to share?',
                  style: context.text.titleSmall,
                ),
                Text(
                  'Record a sermon for review by the ministry team.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Text('RECORD', style: context.text.labelSmall),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
    ),
  );
}

class _FooterVerse extends StatelessWidget {
  const _FooterVerse();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      0,
      AppSpacing.page,
      AppSpacing.xl,
    ),
    child: Column(
      children: [
        const OrnamentDivider(),
        Text(
          '“So faith comes by hearing, and hearing by the word of God.”',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: AppColors.inkSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Romans 10:17 (WEB)',
          style: context.text.bodySmall?.copyWith(color: AppColors.goldDeep),
        ),
      ],
    ),
  );
}
