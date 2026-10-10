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
import '../../../recording/domain/entities/recording_status.dart';
import '../../../recording/domain/entities/recording_submission.dart';
import '../../../recording/presentation/widgets/recording_widgets.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class ReviewQueuePage extends ConsumerStatefulWidget {
  const ReviewQueuePage({super.key});

  @override
  ConsumerState<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends ConsumerState<ReviewQueuePage> {
  ReviewFilter _filter = ReviewFilter.pending;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider(_filter));
    final notifier = ref.read(reviewQueueProvider(_filter).notifier);
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Recording Reviews')),
        body: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FilterBar<ReviewFilter>(
                  values: ReviewFilter.values,
                  selected: _filter,
                  label: (f) => f.label,
                  onSelected: (f) => setState(() => _filter = f),
                ),
              ),
              PagedSliverList<RecordingSubmission>(
                state: queue,
                onLoadMore: notifier.loadMore,
                onRetry: notifier.refresh,
                empty: EmptyView(
                  icon: Icons.inbox_outlined,
                  title: _filter == ReviewFilter.pending
                      ? 'Queue is clear'
                      : 'Nothing here',
                  message: _filter == ReviewFilter.pending
                      ? 'New community recordings will appear here for review.'
                      : null,
                ),
                itemBuilder: (context, r) => AppCard(
                  onTap: () => context.push(Routes.adminReview(r.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.title,
                              style: context.text.headlineSmall,
                            ),
                          ),
                          RecordingStatusChip(status: r.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'by ${r.ownerName.isEmpty ? 'member' : r.ownerName}',
                          formatDuration(Duration(seconds: r.durationSeconds)),
                          if (r.revision > 1) 'revision ${r.revision}',
                          'submitted ${formatRelative(r.submittedAt)}',
                        ].join(' · '),
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

class ReviewDetailPage extends ConsumerWidget {
  const ReviewDetailPage({super.key, required this.recordingId});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(reviewSubmissionProvider(recordingId));
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Review Recording')),
        body: AsyncValueView(
          value: rec,
          onRetry: () => ref.invalidate(reviewSubmissionProvider(recordingId)),
          data: (r) => r == null
              ? const EmptyView(
                  icon: Icons.search_off,
                  title: 'Recording not found',
                )
              : _ReviewBody(recording: r),
        ),
      ),
    );
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.recording});

  final RecordingSubmission recording;

  String get _key => 'review:${recording.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(adminActionProvider(_key));
    final run = ref.read(adminActionProvider(_key).notifier).run;
    final repo = ref.read(recordingReviewRepositoryProvider);
    final r = recording;
    final m = r.metadata;
    final busy = action.isLoading;

    Future<void> decide(RecordingStatus decision) async {
      String? feedback;
      if (RecordingTransitions.requiresFeedback(decision)) {
        feedback = await promptForText(
          context,
          title: decision == RecordingStatus.rejected
              ? 'Reject recording'
              : 'Request changes',
          label: decision == RecordingStatus.rejected
              ? 'Explain why it cannot be published'
              : 'What should the member change?',
          confirmLabel: decision == RecordingStatus.rejected
              ? 'Reject'
              : 'Send feedback',
          validator: Validators.feedback,
        );
        if (feedback == null) return;
      } else {
        final ok = await confirmAction(
          context,
          title: 'Approve recording?',
          message:
              'The member will be notified. Publishing is a separate step.',
          confirmLabel: 'Approve',
        );
        if (!ok) return;
      }
      await run(
        (admin) => repo.decide(r.id, decision, admin, feedback: feedback),
      );
    }

    Future<void> publish() async {
      final result = await showDialog<(String, String)>(
        context: context,
        builder: (_) => _PublishDialog(initialScripture: m.scriptureReference),
      );
      if (result == null) return;
      final ok = await run(
        (admin) => repo.publish(
          r,
          admin,
          category: result.$1,
          scriptureQuote: result.$2,
        ),
      );
      if (ok && context.mounted) {
        showAppSnack(context, 'Published to the sermon library.');
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Row(
          children: [
            RecordingStatusChip(status: r.status),
            const Spacer(),
            Text('Revision ${r.revision}', style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(m.title, style: context.text.displaySmall),
        Text(
          m.speakerName.isEmpty ? r.ownerName : m.speakerName,
          style: context.text.labelLarge?.copyWith(color: AppColors.goldDeep),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaRow(
                'Submitted by',
                r.ownerName.isEmpty ? 'Member' : r.ownerName,
              ),
              _MetaRow(
                'Scripture',
                m.scriptureReference.isEmpty ? '—' : m.scriptureReference,
              ),
              _MetaRow(
                'Duration',
                formatDuration(Duration(seconds: r.durationSeconds)),
              ),
              _MetaRow('File size', formatBytes(r.sizeBytes)),
              _MetaRow('Submitted', formatShortDate(r.submittedAt)),
              if (r.reviewerName != null)
                _MetaRow(
                  'Last reviewed by',
                  '${r.reviewerName} · ${formatShortDate(r.reviewedAt)}',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PreviewPlayer(
          source: StorageSource(r.storagePath),
          label: 'Submitted audio',
        ),
        if (m.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Description', style: context.text.headlineSmall),
          Text(m.description, style: context.text.bodyMedium),
        ],
        if (r.reviewFeedback != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.changesBg,
              borderRadius: AppRadii.control,
            ),
            child: Text(
              'Previous feedback: “${r.reviewFeedback}”',
              style: context.text.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ActionError(state: action),
        ...switch (r.status) {
          RecordingStatus.submitted => [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => run((admin) => repo.startReview(r.id, admin)),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Start review'),
            ),
          ],
          RecordingStatus.underReview => [
            FilledButton.icon(
              onPressed: busy ? null : () => decide(RecordingStatus.approved),
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => decide(RecordingStatus.changesRequested),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Request changes'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: busy ? null : () => decide(RecordingStatus.rejected),
              icon: const Icon(Icons.block),
              label: const Text('Reject'),
            ),
          ],
          RecordingStatus.approved => [
            FilledButton.icon(
              onPressed: busy ? null : publish,
              icon: const Icon(Icons.public),
              label: const Text('Publish to library'),
            ),
          ],
          RecordingStatus.published => [
            if (r.publishedSermonId != null)
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(Routes.adminSermonEdit(r.publishedSermonId!)),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Manage published sermon'),
              ),
          ],
          RecordingStatus.changesRequested => [
            Text(
              'Waiting for the member to resubmit.',
              style: context.text.bodySmall,
            ),
          ],
          RecordingStatus.rejected || RecordingStatus.draft => const <Widget>[],
        },
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: context.text.bodySmall)),
        Expanded(child: Text(value, style: context.text.labelMedium)),
      ],
    ),
  );
}

class _PublishDialog extends StatefulWidget {
  const _PublishDialog({required this.initialScripture});

  final String initialScripture;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  String _category = SermonCategories.all.first;
  final _quote = TextEditingController();

  @override
  void dispose() {
    _quote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Publish to library'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in SermonCategories.all)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _quote,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Key verse text (optional)',
            helperText: widget.initialScripture.isEmpty
                ? null
                : widget.initialScripture,
            alignLabelWithHint: true,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, (_category, _quote.text.trim())),
        child: const Text('Publish'),
      ),
    ],
  );
}
