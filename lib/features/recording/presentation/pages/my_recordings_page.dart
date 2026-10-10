import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/recording_draft.dart';
import '../../domain/entities/recording_status.dart';
import '../../domain/entities/recording_submission.dart';
import '../providers/recording_providers.dart';
import '../widgets/recording_widgets.dart';

/// Local drafts plus submission history with review status.
class MyRecordingsPage extends ConsumerWidget {
  const MyRecordingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider);
    final submissions = ref.watch(mySubmissionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Recordings')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.studio),
        icon: const Icon(Icons.mic),
        label: const Text('New recording'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(draftsProvider);
          ref.invalidate(mySubmissionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            96,
          ),
          children: [
            drafts.when(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Heading('On this device', '${list.length} unsent'),
                        for (final d in list) _DraftTile(draft: d),
                      ],
                    ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const InlineError(
                'Could not load drafts saved on this device.',
              ),
            ),
            const _Heading('Submitted', null),
            submissions.when(
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xl),
                      child: EmptyView(
                        icon: Icons.mic_none,
                        title: 'No submissions yet',
                        message:
                            'Record a sermon of up to 20 minutes and submit it for the ministry team to review.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final s in list) _SubmissionTile(submission: s),
                      ],
                    ),
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(mySubmissionsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.trailing);

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Row(
      children: [
        Text(title, style: context.text.headlineSmall),
        const Spacer(),
        if (trailing != null) Text(trailing!, style: context.text.bodySmall),
      ],
    ),
  );
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.draft});

  final RecordingDraft draft;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      color: AppColors.recessed,
      onTap: () => context.push(Routes.studioSubmit(draft.id)),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: AppColors.goldDeep),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.metadata.title.isEmpty
                      ? 'Untitled recording'
                      : draft.metadata.title,
                  style: context.text.titleSmall,
                ),
                Text(
                  '${formatDuration(draft.duration)} · saved ${formatRelative(draft.updatedAt)}'
                  '${draft.resubmissionOf != null ? ' · resubmission' : ''}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const RecordingStatusChip(status: RecordingStatus.draft),
        ],
      ),
    ),
  );
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission});

  final RecordingSubmission submission;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      onTap: () => context.push(Routes.recording(submission.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineSmall,
                ),
              ),
              RecordingStatusChip(status: submission.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (submission.metadata.scriptureReference.isNotEmpty)
                submission.metadata.scriptureReference,
              formatDuration(Duration(seconds: submission.durationSeconds)),
              'updated ${formatRelative(submission.updatedAt)}',
            ].join(' · '),
            style: context.text.bodySmall,
          ),
          if (submission.reviewFeedback != null &&
              submission.status.ownerCanResubmit) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '“${submission.reviewFeedback}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.changes,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
