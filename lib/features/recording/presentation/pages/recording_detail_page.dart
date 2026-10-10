import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/recording_status.dart';
import '../../domain/entities/recording_submission.dart';
import '../controllers/submission_controller.dart';
import '../providers/recording_providers.dart';
import '../widgets/recording_widgets.dart';

/// Owner's view of a submission: status, reviewer feedback, resubmission.
class RecordingDetailPage extends ConsumerWidget {
  const RecordingDetailPage({super.key, required this.recordingId});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submission = ref.watch(submissionProvider(recordingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Submission')),
      body: AsyncValueView(
        value: submission,
        onRetry: () => ref.invalidate(submissionProvider(recordingId)),
        data: (s) => s == null
            ? const EmptyView(
                icon: Icons.search_off,
                title: 'Submission not found',
                message: 'It may have been removed.',
              )
            : _Detail(submission: s),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.submission});

  final RecordingSubmission submission;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Row(
          children: [
            RecordingStatusChip(status: s.status),
            const Spacer(),
            Text('Revision ${s.revision}', style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(s.title, style: context.text.displaySmall),
        if (s.metadata.speakerName.isNotEmpty)
          Text(
            s.metadata.speakerName,
            style: context.text.labelLarge?.copyWith(color: AppColors.goldDeep),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            if (s.metadata.scriptureReference.isNotEmpty)
              s.metadata.scriptureReference,
            formatDuration(Duration(seconds: s.durationSeconds)),
            if (s.submittedAt != null)
              'submitted ${formatShortDate(s.submittedAt)}',
          ].join(' · '),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _StatusExplainer(submission: s),
        const SizedBox(height: AppSpacing.md),
        PreviewPlayer(
          source: StorageSource(s.storagePath),
          label: 'Your recording',
        ),
        if (s.metadata.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Description', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(s.metadata.description, style: context.text.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ReviewTimeline(submission: s),
        if (s.status.ownerCanResubmit) ...[
          const SizedBox(height: AppSpacing.lg),
          _ResubmitSection(submission: s),
        ],
      ],
    );
  }
}

class _StatusExplainer extends StatelessWidget {
  const _StatusExplainer({required this.submission});

  final RecordingSubmission submission;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final (bg, fg, icon, title, body) = switch (s.status) {
      RecordingStatus.submitted || RecordingStatus.draft => (
        AppColors.pendingBg,
        AppColors.pending,
        Icons.schedule,
        'Pending review',
        'Your recording is in the queue. The ministry team reviews every submission before publication.',
      ),
      RecordingStatus.underReview => (
        AppColors.pendingBg,
        AppColors.pending,
        Icons.hourglass_top,
        'In review',
        'An administrator is reviewing your recording now.',
      ),
      RecordingStatus.changesRequested => (
        AppColors.changesBg,
        AppColors.changes,
        Icons.edit_outlined,
        'Changes requested',
        s.reviewFeedback ?? 'The reviewer asked for changes.',
      ),
      RecordingStatus.rejected => (
        AppColors.errorBg,
        AppColors.error,
        Icons.block,
        'Not accepted',
        s.reviewFeedback ?? 'This recording was not accepted for publication.',
      ),
      RecordingStatus.approved => (
        AppColors.approvedBg,
        AppColors.approved,
        Icons.check_circle_outline,
        'Approved',
        'Your recording was approved and is awaiting publication.',
      ),
      RecordingStatus.published => (
        AppColors.approvedBg,
        AppColors.approved,
        Icons.public,
        'Published',
        'Your sermon is live in the library.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: context.text.titleMedium?.copyWith(color: fg)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            (s.status == RecordingStatus.changesRequested ||
                    s.status == RecordingStatus.rejected)
                ? '“$body”'
                : body,
            style: context.text.bodyMedium,
          ),
          if (s.reviewerName != null && s.reviewFeedback != null) ...[
            const SizedBox(height: 4),
            Text(
              '— ${s.reviewerName}, ${formatShortDate(s.reviewedAt)}',
              style: context.text.bodySmall,
            ),
          ],
          if (s.status == RecordingStatus.published &&
              s.publishedSermonId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () =>
                  context.push(Routes.sermon(s.publishedSermonId!)),
              icon: const Icon(Icons.headphones),
              label: const Text('Open in library'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewTimeline extends StatelessWidget {
  const _ReviewTimeline({required this.submission});

  final RecordingSubmission submission;

  @override
  Widget build(BuildContext context) {
    const steps = [
      RecordingStatus.submitted,
      RecordingStatus.underReview,
      RecordingStatus.approved,
      RecordingStatus.published,
    ];
    final status = submission.status;
    final reachedIndex = switch (status) {
      RecordingStatus.draft => -1,
      RecordingStatus.submitted => 0,
      RecordingStatus.underReview ||
      RecordingStatus.changesRequested ||
      RecordingStatus.rejected => 1,
      RecordingStatus.approved => 2,
      RecordingStatus.published => 3,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REVIEW PROGRESS', style: context.devotionText.overline),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    i <= reachedIndex
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: i <= reachedIndex
                        ? AppColors.primary
                        : AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    steps[i].label,
                    style: context.text.labelLarge?.copyWith(
                      color: i <= reachedIndex
                          ? AppColors.ink
                          : AppColors.inkMuted,
                    ),
                  ),
                  if (i == 1 &&
                      (status == RecordingStatus.changesRequested ||
                          status == RecordingStatus.rejected)) ...[
                    const SizedBox(width: AppSpacing.xs),
                    RecordingStatusChip(status: status),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResubmitSection extends ConsumerStatefulWidget {
  const _ResubmitSection({required this.submission});

  final RecordingSubmission submission;

  @override
  ConsumerState<_ResubmitSection> createState() => _ResubmitSectionState();
}

class _ResubmitSectionState extends ConsumerState<_ResubmitSection> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.submission.metadata.title,
  );
  late final _speaker = TextEditingController(
    text: widget.submission.metadata.speakerName,
  );
  late final _scripture = TextEditingController(
    text: widget.submission.metadata.scriptureReference,
  );
  late final _description = TextEditingController(
    text: widget.submission.metadata.description,
  );

  @override
  void dispose() {
    for (final c in [_title, _speaker, _scripture, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _resubmit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await confirmAction(
      context,
      title: 'Resubmit with current audio?',
      message: 'Your updated details will be sent back to the review queue.',
      confirmLabel: 'Resubmit',
    );
    if (!ok) return;
    final done = await ref
        .read(resubmitControllerProvider(widget.submission.id).notifier)
        .resubmit(
          widget.submission,
          metadataFrom(
            title: _title,
            speaker: _speaker,
            scripture: _scripture,
            description: _description,
          ),
        );
    if (done && mounted) showAppSnack(context, 'Resubmitted for review.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resubmitControllerProvider(widget.submission.id));
    return AppCard(
      color: AppColors.recessed,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Update & resubmit', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Address the reviewer’s feedback by updating the details, re-recording the audio, or both.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SermonMetadataFields(
              title: _title,
              speaker: _speaker,
              scripture: _scripture,
              description: _description,
              enabled: !state.isLoading,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.hasError) ...[
              InlineError(AppException.from(state.error!).message),
              const SizedBox(height: AppSpacing.sm),
            ],
            FilledButton(
              onPressed: state.isLoading ? null : _resubmit,
              child: Text(
                state.isLoading
                    ? 'Resubmitting…'
                    : 'Resubmit with current audio',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => context.push(
                      Uri(
                        path: Routes.studio,
                        queryParameters: {'resubmit': widget.submission.id},
                      ).toString(),
                    ),
              icon: const Icon(Icons.mic),
              label: const Text('Record new audio'),
            ),
          ],
        ),
      ),
    );
  }
}
