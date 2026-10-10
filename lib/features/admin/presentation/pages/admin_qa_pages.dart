import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/paged_list.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../qa/domain/entities/question.dart';
import '../../../qa/presentation/qa_widgets.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class QuestionInboxPage extends ConsumerStatefulWidget {
  const QuestionInboxPage({super.key});

  @override
  ConsumerState<QuestionInboxPage> createState() => _QuestionInboxPageState();
}

class _QuestionInboxPageState extends ConsumerState<QuestionInboxPage> {
  QuestionStatus _status = QuestionStatus.open;

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(questionInboxProvider(_status));
    final notifier = ref.read(questionInboxProvider(_status).notifier);
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Question Inbox')),
        body: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FilterBar<QuestionStatus>(
                  values: QuestionStatus.values,
                  selected: _status,
                  label: (s) =>
                      s == QuestionStatus.open ? 'Unanswered' : s.label,
                  onSelected: (s) => setState(() => _status = s),
                ),
              ),
              PagedSliverList<Question>(
                state: inbox,
                onLoadMore: notifier.loadMore,
                onRetry: notifier.refresh,
                empty: EmptyView(
                  icon: Icons.mark_chat_read_outlined,
                  title: _status == QuestionStatus.open
                      ? 'All questions answered'
                      : 'Nothing here',
                ),
                itemBuilder: (context, q) => AppCard(
                  onTap: () => context.push(Routes.adminQuestion(q.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.category.toUpperCase(),
                              style: context.devotionText.overline,
                            ),
                          ),
                          if (q.visibility == QuestionVisibility.public)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Tooltip(
                                message: 'Asker agreed to public sharing',
                                child: Icon(
                                  Icons.public,
                                  size: 16,
                                  color: AppColors.teal,
                                ),
                              ),
                            ),
                          QuestionStatusChip(status: q.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(q.title, style: context.text.headlineSmall),
                      Text(
                        'Asked ${formatRelative(q.createdAt)}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnswerEditorPage extends ConsumerWidget {
  const AnswerEditorPage({super.key, required this.questionId});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(adminQuestionProvider(questionId));
    final answer = ref.watch(adminAnswerProvider(questionId));
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Answer Question')),
        body: switch ((question, answer)) {
          (AsyncData(value: final q), AsyncData(value: final a)) =>
            q == null
                ? const EmptyView(
                    icon: Icons.search_off,
                    title: 'Question not found',
                  )
                : _AnswerEditor(question: q, answer: a),
          (AsyncError(:final error), _) ||
          (_, AsyncError(:final error)) => ErrorView(
            error: error,
            onRetry: () {
              ref.invalidate(adminQuestionProvider(questionId));
              ref.invalidate(adminAnswerProvider(questionId));
            },
          ),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

class _AnswerEditor extends ConsumerStatefulWidget {
  const _AnswerEditor({required this.question, required this.answer});

  final Question question;
  final OfficialAnswer? answer;

  @override
  ConsumerState<_AnswerEditor> createState() => _AnswerEditorState();
}

class _AnswerEditorState extends ConsumerState<_AnswerEditor> {
  final _form = GlobalKey<FormState>();
  late final _body = TextEditingController(text: widget.answer?.body);

  String get _key => 'qa:${widget.question.id}';

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  String? _validate(String? v) =>
      Validators.required(v, field: 'Answer') ??
      Validators.maxLength(v, Limits.answerBodyMax);

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final a = widget.answer;
    final action = ref.watch(adminActionProvider(_key));
    final run = ref.read(adminActionProvider(_key).notifier).run;
    final repo = ref.read(adminQaRepositoryProvider);
    final published = a?.isPublished ?? false;
    final busy = action.isLoading;

    return Form(
      key: _form,
      child: ListView(
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
          const SizedBox(height: AppSpacing.xs),
          Text(q.title, style: context.text.displaySmall),
          Text(
            [
              'Asked ${formatShortDate(q.createdAt)}',
              if (q.scriptureReference.isNotEmpty) q.scriptureReference,
              q.visibility == QuestionVisibility.public
                  ? 'public once answered'
                  : 'private',
            ].join(' · '),
            style: context.text.bodySmall,
          ),
          if (q.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              color: AppColors.recessed,
              child: Text(q.body, style: context.text.bodyMedium),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ActionError(state: action),
          if (published) ...[
            OfficialAnswerCard(answer: a!),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Withdraw official answer?',
                        message:
                            'The question returns to the unanswered inbox and the answer becomes a draft.',
                        confirmLabel: 'Withdraw',
                        destructive: true,
                      );
                      if (ok) {
                        await run((admin) => repo.unpublishAnswer(q, admin));
                      }
                    },
              icon: const Icon(Icons.undo),
              label: const Text('Withdraw to edit'),
            ),
          ] else ...[
            Text('Official answer', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            if (a != null)
              Text(
                'Draft saved ${formatRelative(a.updatedAt)} by ${a.adminName}',
                style: context.text.bodySmall,
              ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _body,
              enabled: q.status != QuestionStatus.closed,
              minLines: 8,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Write a pastoral, scripture-grounded answer…',
                alignLabelWithHint: true,
              ),
              validator: _validate,
            ),
            const SizedBox(height: AppSpacing.md),
            if (q.status == QuestionStatus.closed)
              Text(
                'Reopen this question to answer it.',
                style: context.text.bodySmall,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!(_form.currentState?.validate() ?? false)) {
                                return;
                              }
                              final ok = await run(
                                (admin) => repo.saveDraftAnswer(
                                  q.id,
                                  _body.text,
                                  admin,
                                ),
                              );
                              if (ok && context.mounted) {
                                showAppSnack(context, 'Draft saved.');
                              }
                            },
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!(_form.currentState?.validate() ?? false)) {
                                return;
                              }
                              final ok = await confirmAction(
                                context,
                                title: 'Publish official answer?',
                                message:
                                    q.visibility == QuestionVisibility.public
                                    ? 'The asker will be notified, and the question will appear in the community archive without their name.'
                                    : 'The asker will be notified. The question stays private.',
                                confirmLabel: 'Publish',
                              );
                              if (!ok) return;
                              final done = await run(
                                (admin) =>
                                    repo.publishAnswer(q, _body.text, admin),
                              );
                              if (done && context.mounted) {
                                showAppSnack(context, 'Answer published.');
                              }
                            },
                      child: const Text('Publish answer'),
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          if (q.status == QuestionStatus.open)
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Close without answering?',
                        message:
                            'Use this for duplicates or questions outside the ministry’s scope.',
                        confirmLabel: 'Close',
                        destructive: true,
                      );
                      if (ok) {
                        await run(
                          (admin) => repo.setQuestionStatus(
                            q,
                            QuestionStatus.closed,
                            admin,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Close question'),
            ),
          if (q.status == QuestionStatus.closed)
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => run(
                      (admin) =>
                          repo.setQuestionStatus(q, QuestionStatus.open, admin),
                    ),
              icon: const Icon(Icons.lock_open),
              label: const Text('Reopen question'),
            ),
        ],
      ),
    );
  }
}
