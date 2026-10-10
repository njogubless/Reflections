import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../home/presentation/widgets/header_actions.dart';
import '../domain/entities/question.dart';
import 'qa_providers.dart';
import 'qa_widgets.dart';

/// Questions tab: ask, own history, and the community answer archive.
class QuestionsPage extends ConsumerWidget {
  const QuestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = ref.watch(communityQuestionsProvider);
    final notifier = ref.read(communityQuestionsProvider.notifier);
    final mine = ref.watch(myQuestionsProvider).value ?? const [];
    final openCount = mine.where((q) => q.status == QuestionStatus.open).length;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              titleSpacing: AppSpacing.page,
              title: BrandTitle(section: 'Questions'),
              actions: [HeaderActions()],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  0,
                ),
                child: AppCard(
                  color: AppColors.surfaceLow,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            size: 18,
                            color: AppColors.goldDeep,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'THEOLOGICAL DISCOURSE',
                            style: context.devotionText.overline,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ask Pastors & Biblical Scholars',
                        style: context.text.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Submit questions on doctrine, spiritual formation, or biblical context. The ministry team publishes official answers.',
                        style: context.text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.push(Routes.askQuestion),
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Ask question'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.push(Routes.myQuestions),
                              child: Text(
                                openCount > 0
                                    ? 'My questions ($openCount open)'
                                    : 'My questions',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                overline: 'Community',
                title: 'Recently answered',
              ),
            ),
            PagedSliverList<Question>(
              state: community,
              onLoadMore: notifier.loadMore,
              onRetry: notifier.refresh,
              itemBuilder: (_, q) =>
                  _QuestionTile(question: q, showOwnerHint: false),
              empty: const EmptyView(
                icon: Icons.help_outline,
                title: 'No public answers yet',
                message:
                    'Answered questions that askers choose to share will appear here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question, required this.showOwnerHint});

  final Question question;
  final bool showOwnerHint;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => context.push(Routes.question(question.id)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                question.category.toUpperCase(),
                style: context.devotionText.overline,
              ),
            ),
            QuestionStatusChip(status: question.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '“${question.title}”',
          style: context.text.headlineSmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          question.status == QuestionStatus.answered
              ? 'Answered by ${question.answeredByName ?? 'the ministry team'} · ${formatRelative(question.answeredAt)}'
              : 'Asked ${formatRelative(question.createdAt)}'
                    '${showOwnerHint && question.visibility == QuestionVisibility.public ? ' · shared publicly once answered' : ''}',
          style: context.text.bodySmall,
        ),
      ],
    ),
  );
}

class AskQuestionPage extends ConsumerStatefulWidget {
  const AskQuestionPage({super.key});

  @override
  ConsumerState<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends ConsumerState<AskQuestionPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _scripture = TextEditingController();
  String _category = QuestionCategories.all.first;
  bool _public = false;

  @override
  void dispose() {
    for (final c in [_title, _body, _scripture]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final id = await ref
        .read(questionActionsProvider.notifier)
        .ask(
          NewQuestion(
            title: _title.text,
            body: _body.text,
            category: _category,
            scriptureReference: _scripture.text,
            visibility: _public
                ? QuestionVisibility.public
                : QuestionVisibility.private,
          ),
        );
    if (id != null && mounted) {
      showAppSnack(
        context,
        'Question sent. You will be notified when it is answered.',
      );
      context.pushReplacement(Routes.question(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ask a Question')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              'Your question is reviewed and answered by the ministry team.',
              style: context.text.bodyMedium?.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your question *',
                hintText: 'How do we practise Sabbath rest today?',
              ),
              validator: Validators.title,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _body,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                alignLabelWithHint: true,
              ),
              validator: (v) => Validators.maxLength(v, Limits.questionBodyMax),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Topic'),
              items: [
                for (final c in QuestionCategories.all)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _scripture,
              decoration: const InputDecoration(
                labelText: 'Related scripture (optional)',
              ),
              validator: Validators.optionalShort,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _public,
              onChanged: (v) => setState(() => _public = v),
              title: const Text('Share with the community once answered'),
              subtitle: const Text(
                'Your name is never shown. Leave off to keep it private.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.hasError) ...[
              InlineError(AppException.from(state.error!).message),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton.icon(
              onPressed: state.isLoading ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(state.isLoading ? 'Sending…' : 'Send question'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyQuestionsPage extends ConsumerWidget {
  const MyQuestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myQuestionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Questions')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.askQuestion),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Ask'),
      ),
      body: AsyncValueView(
        value: mine,
        onRetry: () => ref.invalidate(myQuestionsProvider),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.help_outline,
                title: 'No questions yet',
                message:
                    'Ask about doctrine, scripture, prayer or church life.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  96,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) =>
                    _QuestionTile(question: list[i], showOwnerHint: true),
              ),
      ),
    );
  }
}

class QuestionDetailPage extends ConsumerWidget {
  const QuestionDetailPage({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(questionProvider(questionId));
    final answer = ref.watch(officialAnswerProvider(questionId));
    final uid = ref.watch(currentUserProvider)?.uid;
    final actions = ref.watch(questionActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Question')),
      body: AsyncValueView(
        value: question,
        onRetry: () => ref.invalidate(questionProvider(questionId)),
        data: (q) {
          if (q == null) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'Question not found',
            );
          }
          final isOwner = q.ownerUid == uid;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Row(
                children: [
                  Text(
                    q.category.toUpperCase(),
                    style: context.devotionText.overline,
                  ),
                  const Spacer(),
                  QuestionStatusChip(status: q.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(q.title, style: context.text.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (isOwner)
                    'You asked ${formatRelative(q.createdAt)}'
                  else
                    'Asked by a member',
                  if (q.scriptureReference.isNotEmpty) q.scriptureReference,
                  if (isOwner)
                    q.visibility == QuestionVisibility.public
                        ? 'Public once answered'
                        : 'Private',
                ].join(' · '),
                style: context.text.bodySmall,
              ),
              if (q.body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(q.body, style: context.text.bodyLarge),
              ],
              const SizedBox(height: AppSpacing.lg),
              answer.when(
                data: (a) => a != null
                    ? OfficialAnswerCard(answer: a)
                    : AppCard(
                        color: AppColors.pendingBg,
                        border: false,
                        child: MetaItem(
                          icon: q.status == QuestionStatus.closed
                              ? Icons.lock_outline
                              : Icons.schedule,
                          label: q.status == QuestionStatus.closed
                              ? 'This question was closed without an answer.'
                              : 'Awaiting an official answer from the ministry team.',
                          color: AppColors.pending,
                        ),
                      ),
                loading: () => const LoadingView(),
                error: (e, _) => InlineError(AppException.from(e).message),
              ),
              if (isOwner && q.status == QuestionStatus.open) ...[
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: actions.isLoading
                      ? null
                      : () async {
                          final ok = await confirmAction(
                            context,
                            title: 'Withdraw this question?',
                            message:
                                'It will be closed and no longer awaits an answer.',
                            confirmLabel: 'Withdraw',
                            destructive: true,
                          );
                          if (ok) {
                            await ref
                                .read(questionActionsProvider.notifier)
                                .close(q.id);
                          }
                        },
                  icon: const Icon(Icons.close),
                  label: const Text('Withdraw question'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
