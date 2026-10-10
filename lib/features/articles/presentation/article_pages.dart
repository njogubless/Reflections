import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/pagination/paged.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_image.dart';
import '../data/article_data.dart';
import '../domain/entities/article.dart';
import '../domain/repositories/article_repository.dart';

final articleRepositoryProvider = Provider<ArticleRepository>(
  (ref) => FirestoreArticleRepository(ref.watch(firestoreProvider)),
);

final latestArticlesProvider = StreamProvider.autoDispose<List<Article>>(
  (ref) => ref.watch(articleRepositoryProvider).watchLatest(),
);

final articleDetailProvider = FutureProvider.autoDispose
    .family<Article, String>(
      (ref, id) => ref.watch(articleRepositoryProvider).getPublished(id),
    );

class ArticleFeed extends PagedNotifier<Article> {
  ArticleFeed(this.category);
  final String? category;

  @override
  Future<PageResult<Article>> fetchPage(Object? cursor, int limit) => ref
      .read(articleRepositoryProvider)
      .fetchPublished(category: category, cursor: cursor, limit: limit);
}

final articleFeedProvider = NotifierProvider.autoDispose
    .family<ArticleFeed, PagedState<Article>, String?>(ArticleFeed.new);

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    onTap: () => context.push(Routes.article(article.id)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (article.coverStoragePath != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: StorageImage(path: article.coverStoragePath),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.category.toUpperCase(),
                style: context.devotionText.overline,
              ),
              const SizedBox(height: 4),
              Text(article.title, style: context.text.headlineSmall),
              if (article.summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  article.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Flexible(
                    child: MetaItem(
                      icon: Icons.person_outline,
                      label: article.authorName,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (article.readMinutes > 0)
                    MetaItem(
                      icon: Icons.schedule,
                      label: '${article.readMinutes} min read',
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

/// Renders structured article blocks. Text only; nothing is interpreted as markup.
class ArticleBody extends StatelessWidget {
  const ArticleBody({super.key, required this.blocks});

  final List<ArticleBlock> blocks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final b in blocks)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: switch (b.type) {
            ArticleBlockType.heading => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(b.text, style: context.text.headlineMedium),
            ),
            ArticleBlockType.paragraph => Text(
              b.text,
              style: context.text.bodyLarge,
            ),
            ArticleBlockType.quote => Container(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.gold, width: 3),
                ),
              ),
              child: Text(
                b.text,
                style: context.text.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            ArticleBlockType.scripture => AppCard(
              color: AppColors.recessed,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote, color: AppColors.goldDeep),
                  Text(
                    '“${b.text}”',
                    style: context.devotionText.scriptureQuote,
                  ),
                  if (b.reference != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '— ${b.reference}',
                        style: context.text.labelMedium,
                      ),
                    ),
                ],
              ),
            ),
          },
        ),
    ],
  );
}

class ArticleReaderPage extends ConsumerWidget {
  const ArticleReaderPage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(articleDetailProvider(articleId));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncValueView(
        value: article,
        onRetry: () => ref.invalidate(articleDetailProvider(articleId)),
        data: (a) => ArticleView(article: a),
      ),
    );
  }
}

/// Shared by the reader and the admin preview.
class ArticleView extends StatelessWidget {
  const ArticleView({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      0,
      AppSpacing.page,
      AppSpacing.xl,
    ),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                article.category.toUpperCase(),
                style: context.devotionText.overline,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(article.title, style: context.text.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  article.authorName,
                  if (article.publishedAt != null)
                    formatShortDate(article.publishedAt),
                  if (article.readMinutes > 0)
                    '${article.readMinutes} min read',
                ].join(' · '),
                style: context.text.bodySmall,
              ),
              if (article.coverStoragePath != null) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadii.card,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: StorageImage(path: article.coverStoragePath),
                  ),
                ),
              ],
              if (article.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  article.summary,
                  style: context.text.bodyLarge?.copyWith(
                    color: AppColors.inkSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const OrnamentDivider(),
              ArticleBody(blocks: article.blocks),
              if (article.tags.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final t in article.tags) Chip(label: Text('#$t')),
                  ],
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Category list exported for the feed's filter chips.
const articleCategories = ArticleCategories.all;
