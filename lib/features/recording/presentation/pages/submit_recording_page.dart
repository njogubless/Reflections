import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/upload_progress_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/recording_draft.dart';
import '../../domain/entities/recording_submission.dart';
import '../controllers/submission_controller.dart';
import '../providers/recording_providers.dart';
import '../widgets/recording_widgets.dart';

/// Preview a local draft, edit its metadata, and submit it for review.
class SubmitRecordingPage extends ConsumerWidget {
  const SubmitRecordingPage({super.key, required this.draftId});

  final String draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftProvider(draftId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Submit')),
      body: AsyncValueView(
        value: draft,
        onRetry: () => ref.invalidate(draftProvider(draftId)),
        data: (d) => d == null
            ? EmptyView(
                icon: Icons.mic_off_outlined,
                title: 'Draft not found',
                message: 'This draft may have been submitted or deleted.',
                action: FilledButton(
                  onPressed: () => context.go(Routes.myRecordings),
                  child: const Text('My recordings'),
                ),
              )
            : _SubmitForm(draft: d),
      ),
    );
  }
}

class _SubmitForm extends ConsumerStatefulWidget {
  const _SubmitForm({required this.draft});

  final RecordingDraft draft;

  @override
  ConsumerState<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends ConsumerState<_SubmitForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.draft.metadata.title);
  late final _speaker = TextEditingController(
    text: widget.draft.metadata.speakerName.isNotEmpty
        ? widget.draft.metadata.speakerName
        : ref.read(currentUserProvider)?.displayName ?? '',
  );
  late final _scripture = TextEditingController(
    text: widget.draft.metadata.scriptureReference,
  );
  late final _description = TextEditingController(
    text: widget.draft.metadata.description,
  );

  @override
  void dispose() {
    for (final c in [_title, _speaker, _scripture, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  SermonMetadata get _meta => metadataFrom(
    title: _title,
    speaker: _speaker,
    scripture: _scripture,
    description: _description,
  );

  Future<void> _saveDraft() async {
    await ref
        .read(submissionControllerProvider(widget.draft.id).notifier)
        .saveMetadata(widget.draft, _meta);
    ref.invalidate(draftsProvider);
    if (mounted) showAppSnack(context, 'Draft saved on this device.');
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await confirmAction(
      context,
      title: 'Submit for review?',
      message:
          'Your recording will be uploaded and reviewed by the ministry team. It will not be published until an administrator approves it.',
      confirmLabel: 'Submit',
    );
    if (!ok) return;
    final submitted = await ref
        .read(submissionControllerProvider(widget.draft.id).notifier)
        .submit(widget.draft, _meta);
    if (submitted && mounted) {
      showAppSnack(
        context,
        'Submitted for review. We will notify you when it is reviewed.',
      );
      context.go(Routes.myRecordings);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete draft?',
      message: 'This recording will be permanently removed from this device.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(draftRepositoryProvider).delete(widget.draft.id);
    ref.invalidate(draftsProvider);
    if (mounted) context.go(Routes.myRecordings);
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(submissionControllerProvider(widget.draft.id));
    final controller = ref.read(
      submissionControllerProvider(widget.draft.id).notifier,
    );
    final busy = submit.busy;
    return PopScope(
      canPop: !busy,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.draft.resubmissionOf != null
                            ? 'RESUBMISSION'
                            : 'DRAFT',
                        style: context.devotionText.overline,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.circle, size: 6, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(widget.draft.duration),
                        style: context.text.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        'Saved ${formatRelative(widget.draft.updatedAt)}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PreviewPlayer(source: LocalFileSource(widget.draft.filePath)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Sermon details', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            SermonMetadataFields(
              title: _title,
              speaker: _speaker,
              scripture: _scripture,
              description: _description,
              enabled: !busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (submit.phase == SubmitPhase.uploading ||
                submit.phase == SubmitPhase.saving)
              UploadProgressCard(
                label: submit.phase == SubmitPhase.saving
                    ? 'Finalizing submission'
                    : 'Uploading',
                progress: submit.progress,
                onCancel: submit.phase == SubmitPhase.uploading
                    ? controller.cancelUpload
                    : null,
              ),
            if (submit.phase == SubmitPhase.failed && submit.error != null)
              UploadProgressCard(
                label: 'Submission',
                progress: null,
                error: submit.error!.message,
                onRetry: _submit,
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(busy ? 'Submitting…' : 'Submit for review'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : _saveDraft,
                    child: const Text('Save draft'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
