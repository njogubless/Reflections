import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../articles/presentation/article_pages.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../books/presentation/book_providers.dart';
import '../../../qa/presentation/qa_providers.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../../../sermons/presentation/controllers/audio_player_controller.dart';
import '../../../sermons/presentation/providers/sermon_providers.dart';
import '../../../sermons/presentation/widgets/sermon_widgets.dart';
import '../../domain/daily_verse.dart';
import '../widgets/header_actions.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final now = DateTime.now();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(featuredSermonProvider)
            ..invalidate(recentSermonsProvider)
            ..invalidate(continueListeningProvider)
            ..invalidate(latestBooksProvider)
            ..invalidate(latestArticlesProvider)
            ..invalidate(recentlyAnsweredProvider);
          await ref.read(authRepositoryProvider).refreshClaims();
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              titleSpacing: AppSpacing.page,
              title: BrandTitle(section: 'Home'),
              actions: [HeaderActions()],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              sliver: SliverList.list(
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d').format(now).toUpperCase(),
                    style: context.devotionText.overline,
                  ),
                  Text(
                    'Grace and peace, ${user?.firstName ?? 'friend'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _VerseOfTheDay(verse: DailyVerse.forDate(now)),
                  const SizedBox(height: AppSpacing.md),
                  const _FeaturedSection(),
                  const _ContinueListening(),
                  if (RecordingPolicy.canRecord(user)) ...[
                    const SizedBox(height: AppSpacing.md),
                    const _StudioCard(),
                  ],
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                overline: 'New · Pulpit feed',
                title: 'Recent Sermons',
                actionLabel: 'View all',
                onAction: () => context.go(Routes.sermons),
              ),
            ),
            const SliverToBoxAdapter(child: _RecentSermons()),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _ReadingSpotlight(),
                  SizedBox(height: AppSpacing.md),
                  _DiscourseCard(),
                  SizedBox(height: AppSpacing.xl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseOfTheDay extends StatelessWidget {
  const _VerseOfTheDay({required this.verse});

  final DailyVerse verse;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GoldTag(label: 'Verse of the day', icon: Icons.auto_awesome),
        const SizedBox(height: AppSpacing.md),
        Text('“${verse.text}”', style: context.devotionText.scriptureQuote),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              '— ${verse.reference}',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.goldDeep,
              ),
            ),
            const Spacer(),
            Text(DailyVerse.translation, style: context.text.bodySmall),
          ],
        ),
      ],
    ),
  );
}

class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredSermonProvider);
    return featured.when(
      data: (s) => s == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: FeaturedSermonCard(sermon: s, label: 'Featured message'),
            ),
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _ContinueListening extends ConsumerWidget {
  const _ContinueListening();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(continueListeningProvider).value;
    if (progress == null) return const SizedBox.shrink();
    return AppCard(
      onTap: () => context.push(Routes.sermon(progress.sermonId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 16, color: AppColors.goldDeep),
              const SizedBox(width: 4),
              Text('CONTINUE LISTENING', style: context.devotionText.overline),
              const Spacer(),
              Text(
                '${progress.remaining.inMinutes}m left',
                style: context.text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(progress.title, style: context.text.headlineSmall),
                    Text(
                      [
                        progress.speakerName,
                        progress.scriptureReference,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryInk,
                ),
                tooltip: 'Resume',
                onPressed: () async {
                  try {
                    final sermon = await ref.read(
                      sermonDetailProvider(progress.sermonId).future,
                    );
                    await ref
                        .read(audioPlayerControllerProvider.notifier)
                        .playSermon(sermon);
                  } catch (e) {
                    if (context.mounted) {
                      showAppSnack(
                        context,
                        'That sermon is no longer available.',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadii.pill,
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              color: AppColors.goldDeep,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                formatDuration(progress.position),
                style: context.text.labelSmall,
              ),
              const Spacer(),
              Text(
                '${formatDuration(progress.duration)} (${(progress.fraction * 100).round()}%)',
                style: context.text.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard();

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.surfaceLow,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.goldContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.mic_external_on, color: AppColors.goldDeep),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MINISTER’S STUDIO', style: context.devotionText.overline),
              Text('Record a Sermon', style: context.text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Record and submit an audio homily (up to 20 minutes) for review.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push(Routes.studio),
                    icon: const Icon(Icons.radio_button_checked, size: 18),
                    label: const Text('Start recording'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push(Routes.myRecordings),
                    child: const Text('My recordings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecentSermons extends ConsumerWidget {
  const _RecentSermons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSermonsProvider);
    return SizedBox(
      height: 262,
      child: switch (recent) {
        AsyncData(value: final List<Sermon> list) when list.isEmpty =>
          const EmptyView(
            icon: Icons.headphones_outlined,
            title: 'No sermons yet',
            message: 'New sermons will appear here.',
          ),
        AsyncData(value: final List<Sermon> list) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) => SermonTile(sermon: list[i]),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(recentSermonsProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _ReadingSpotlight extends ConsumerWidget {
  const _ReadingSpotlight();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(latestBooksProvider).value;
    final articles = ref.watch(latestArticlesProvider).value;
    final book = (books == null || books.isEmpty)
        ? null
        : books.firstWhere((b) => b.featured, orElse: () => books.first);
    final article = (articles == null || articles.isEmpty)
        ? null
        : articles.first;
    if (book == null && article == null) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                size: 16,
                color: AppColors.goldDeep,
              ),
              const SizedBox(width: 4),
              Text('READING SPOTLIGHT', style: context.devotionText.overline),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (book != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.base),
                  child: SizedBox(
                    width: 84,
                    height: 112,
                    child: StorageImage(
                      path: book.coverStoragePath,
                      fallbackIcon: Icons.menu_book,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: context.text.headlineSmall),
                      Text(book.author, style: context.text.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        book.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(Routes.book(book.id)),
                icon: const Icon(Icons.menu_book),
                label: const Text('Read book'),
              ),
            ),
          ],
          if (article != null) ...[
            if (book != null) const Divider(height: AppSpacing.xl),
            InkWell(
              onTap: () => context.push(Routes.article(article.id)),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, color: AppColors.goldDeep),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LATEST ARTICLE', style: context.text.labelSmall),
                        Text(article.title, style: context.text.titleSmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscourseCard extends ConsumerWidget {
  const _DiscourseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyAnsweredProvider).value;
    final q = (recent == null || recent.isEmpty) ? null : recent.first;
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 16,
                color: AppColors.goldDeep,
              ),
              const SizedBox(width: 4),
              Text(
                'THEOLOGICAL DISCOURSE',
                style: context.devotionText.overline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ask Pastors & Biblical Scholars',
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Submit questions on doctrine, spiritual formation, or biblical context.',
            style: context.text.bodyMedium,
          ),
          if (q != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: () => context.push(Routes.question(q.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 16,
                        color: AppColors.goldDeep,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'RECENTLY ANSWERED',
                        style: context.devotionText.overline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '“${q.title}”',
                    style: context.text.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    'Answered by ${q.answeredByName ?? 'the ministry team'}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => context.push(Routes.askQuestion),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Ask question'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(Routes.questions),
                child: const Text('Explore →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
