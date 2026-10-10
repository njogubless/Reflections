import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/activity_entry.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final activity = ref.watch(recentActivityProvider);
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Admin Workspace')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardMetricsProvider);
            ref.invalidate(recentActivityProvider);
            await ref.read(dashboardMetricsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text('OVERVIEW', style: context.devotionText.overline),
              const SizedBox(height: AppSpacing.sm),
              metrics.when(
                data: (m) => GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 600
                      ? 3
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.0,
                  children: [
                    MetricTile(
                      label: 'Pending recording reviews',
                      value: '${m.pendingReviews}',
                      icon: Icons.rate_review_outlined,
                      highlight: m.pendingReviews > 0,
                      onTap: () => context.push(Routes.adminReviews),
                    ),
                    MetricTile(
                      label: 'Unanswered questions',
                      value: '${m.unansweredQuestions}',
                      icon: Icons.forum_outlined,
                      highlight: m.unansweredQuestions > 0,
                      onTap: () => context.push(Routes.adminQuestions),
                    ),
                    MetricTile(
                      label: 'Published sermons',
                      value: '${m.publishedSermons}',
                      icon: Icons.headphones_outlined,
                      onTap: () => context.push(Routes.adminSermons),
                    ),
                    MetricTile(
                      label: 'Published books',
                      value: '${m.publishedBooks}',
                      icon: Icons.menu_book_outlined,
                      onTap: () => context.push(Routes.adminBooks),
                    ),
                    MetricTile(
                      label: 'Published articles',
                      value: '${m.publishedArticles}',
                      icon: Icons.article_outlined,
                      onTap: () => context.push(Routes.adminArticles),
                    ),
                    MetricTile(
                      label: 'Drafts in progress',
                      value: '${m.draftItems}',
                      icon: Icons.edit_note,
                    ),
                  ],
                ),
                loading: () =>
                    const SizedBox(height: 200, child: LoadingView()),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(dashboardMetricsProvider),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('QUICK ACTIONS', style: context.devotionText.overline),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _Quick(
                    Icons.upload_file,
                    'Upload sermon',
                    Routes.adminSermonNew,
                  ),
                  _Quick(
                    Icons.rate_review_outlined,
                    'Review recordings',
                    Routes.adminReviews,
                  ),
                  _Quick(
                    Icons.forum_outlined,
                    'Answer questions',
                    Routes.adminQuestions,
                  ),
                  _Quick(
                    Icons.edit_note,
                    'Write article',
                    Routes.adminArticleNew,
                  ),
                  _Quick(
                    Icons.library_add_outlined,
                    'Add book',
                    Routes.adminBookNew,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('MANAGE', style: context.devotionText.overline),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (icon, label, route) in const [
                      (
                        Icons.headphones_outlined,
                        'Sermon uploads',
                        Routes.adminSermons,
                      ),
                      (
                        Icons.mic_none,
                        'Recording reviews',
                        Routes.adminReviews,
                      ),
                      (Icons.menu_book_outlined, 'Books', Routes.adminBooks),
                      (
                        Icons.article_outlined,
                        'Articles',
                        Routes.adminArticles,
                      ),
                      (
                        Icons.forum_outlined,
                        'Question inbox',
                        Routes.adminQuestions,
                      ),
                    ])
                      ListTile(
                        leading: Icon(icon),
                        title: Text(label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(route),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('RECENT ACTIVITY', style: context.devotionText.overline),
              const SizedBox(height: AppSpacing.sm),
              activity.when(
                data: (items) => items.isEmpty
                    ? const EmptyView(
                        icon: Icons.history,
                        title: 'No activity yet',
                        message: 'Admin actions are logged here.',
                      )
                    : AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final a in items) _ActivityTile(entry: a),
                          ],
                        ),
                      ),
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(recentActivityProvider),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18, color: AppColors.goldDeep),
    label: Text(label),
    labelStyle: context.text.labelMedium,
    onPressed: () => context.push(route),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.entityType) {
      'sermon' => Icons.headphones_outlined,
      'recording' => Icons.mic_none,
      'book' => Icons.menu_book_outlined,
      'article' => Icons.article_outlined,
      'question' => Icons.forum_outlined,
      _ => Icons.history,
    };
    return ListTile(
      leading: Icon(icon, color: AppColors.goldDeep),
      title: Text(entry.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${entry.actorName} · ${formatRelative(entry.createdAt)}'),
    );
  }
}
