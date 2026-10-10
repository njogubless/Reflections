import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/domain/content_status.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/media/file_picking.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/paged_list.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../../core/widgets/upload_progress_card.dart';
import '../../../recording/presentation/widgets/recording_widgets.dart';
import '../../../sermons/domain/entities/sermon.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class AdminSermonsPage extends ConsumerStatefulWidget {
  const AdminSermonsPage({super.key});

  @override
  ConsumerState<AdminSermonsPage> createState() => _AdminSermonsPageState();
}

class _AdminSermonsPageState extends ConsumerState<AdminSermonsPage> {
  ContentStatus? _status;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminSermonListProvider(_status));
    final notifier = ref.read(adminSermonListProvider(_status).notifier);
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Sermon Uploads')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => context.push(Routes.adminSermonNew),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload sermon'),
        ),
        body: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FilterBar<ContentStatus?>(
                  values: const [null, ...ContentStatus.values],
                  selected: _status,
                  label: (s) => s?.label ?? 'All',
                  onSelected: (s) => setState(() => _status = s),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'Admin-uploaded audio only. Community recordings are handled in Recording Reviews.',
                  ),
                ),
              ),
              PagedSliverList<Sermon>(
                state: list,
                onLoadMore: notifier.loadMore,
                onRetry: notifier.refresh,
                empty: const EmptyView(
                  icon: Icons.headphones_outlined,
                  title: 'No sermons here',
                  message: 'Upload an audio file to create a sermon.',
                ),
                itemBuilder: (context, s) => AppCard(
                  onTap: () => context.push(Routes.adminSermonEdit(s.id)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: context.text.headlineSmall),
                            Text(
                              [
                                s.speakerName,
                                if (s.durationSeconds > 0)
                                  formatMinutes(s.durationSeconds),
                                s.sourceType == SermonSource.userSubmission
                                    ? 'community recording'
                                    : (s.hasAudio
                                          ? 'audio uploaded'
                                          : 'no audio yet'),
                              ].where((e) => e.isNotEmpty).join(' · '),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (s.featured)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.star,
                            color: AppColors.gold,
                            size: 18,
                          ),
                        ),
                      ContentStatusChip(status: s.status),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create (sermonId == null) or edit an admin-managed sermon.
class AdminSermonEditorPage extends ConsumerStatefulWidget {
  const AdminSermonEditorPage({super.key, this.sermonId});

  final String? sermonId;

  @override
  ConsumerState<AdminSermonEditorPage> createState() =>
      _AdminSermonEditorPageState();
}

class _AdminSermonEditorPageState extends ConsumerState<AdminSermonEditorPage> {
  late final String _id =
      widget.sermonId ?? ref.read(adminSermonRepositoryProvider).newId();
  late bool _isNew = widget.sermonId == null;

  @override
  Widget build(BuildContext context) {
    if (_isNew) {
      return AdminGate(
        child: Scaffold(
          appBar: AppBar(title: const Text('New Sermon')),
          body: _SermonForm(
            id: _id,
            initial: null,
            onCreated: () => setState(() => _isNew = false),
          ),
        ),
      );
    }
    final sermon = ref.watch(adminSermonProvider(_id));
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Sermon')),
        body: AsyncValueView(
          value: sermon,
          onRetry: () => ref.invalidate(adminSermonProvider(_id)),
          data: (s) => s == null
              ? const EmptyView(
                  icon: Icons.search_off,
                  title: 'Sermon not found',
                )
              : _SermonForm(id: _id, initial: s),
        ),
      ),
    );
  }
}

class _SermonForm extends ConsumerStatefulWidget {
  const _SermonForm({required this.id, required this.initial, this.onCreated});

  final String id;
  final Sermon? initial;
  final VoidCallback? onCreated;

  @override
  ConsumerState<_SermonForm> createState() => _SermonFormState();
}

class _SermonFormState extends ConsumerState<_SermonForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _speaker = TextEditingController(
    text: widget.initial?.speakerName,
  );
  late final _scripture = TextEditingController(
    text: widget.initial?.scriptureReference,
  );
  late final _quote = TextEditingController(
    text: widget.initial?.scriptureQuote,
  );
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late String _category = widget.initial?.category.isNotEmpty == true
      ? widget.initial!.category
      : SermonCategories.all.first;
  late bool _featured = widget.initial?.featured ?? false;

  @override
  void dispose() {
    for (final c in [_title, _speaker, _scripture, _quote, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Sermon _build() {
    final base =
        widget.initial ??
        Sermon(
          id: widget.id,
          title: '',
          description: '',
          speakerName: '',
          scriptureReference: '',
          category: _category,
          sourceType: SermonSource.adminPublished,
          status: ContentStatus.draft,
          storagePath: null,
          durationSeconds: 0,
        );
    return base.copyWith(
      title: _title.text.trim(),
      speakerName: _speaker.text.trim(),
      scriptureReference: _scripture.text.trim(),
      scriptureQuote: _quote.text.trim(),
      description: _description.text.trim(),
      category: _category,
      featured: _featured,
    );
  }

  String get _actionKey => 'sermon:${widget.id}';

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final isNew = widget.initial == null;
    final ok = await ref
        .read(adminActionProvider(_actionKey).notifier)
        .run(
          (admin) => ref
              .read(adminSermonRepositoryProvider)
              .saveMetadata(_build(), admin, isNew: isNew),
        );
    if (ok && mounted) {
      showAppSnack(
        context,
        isNew ? 'Draft created. Now upload the audio.' : 'Changes saved.',
      );
      widget.onCreated?.call();
    }
  }

  Future<void> _pickAudio() async {
    final slot = ref.read(uploadSlotProvider('audio:${widget.id}').notifier);
    try {
      final picked = await pickLocalFile(PickKind.audio);
      if (picked == null) return;
      final duration = await probeAudioDuration(picked.file);
      final repo = ref.read(adminSermonRepositoryProvider);
      await slot.run(
        fileName: picked.name,
        start: () =>
            repo.uploadAudio(widget.id, picked.file, picked.contentType),
        attach: () => repo.attachAudio(
          widget.id,
          durationSeconds: duration?.inSeconds ?? 0,
          sizeBytes: picked.sizeBytes,
        ),
      );
    } on AppException catch (e) {
      slot.fail(e);
    }
  }

  Future<void> _pickCover() async {
    final slot = ref.read(uploadSlotProvider('cover:${widget.id}').notifier);
    try {
      final picked = await pickLocalFile(PickKind.image);
      if (picked == null) return;
      final repo = ref.read(adminSermonRepositoryProvider);
      await slot.run(
        fileName: picked.name,
        start: () =>
            repo.uploadCover(widget.id, picked.file, picked.contentType),
        attach: () => repo.attachCover(widget.id),
      );
    } on AppException catch (e) {
      slot.fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(adminActionProvider(_actionKey));
    final sermon = widget.initial;
    final created = sermon != null;
    final isSubmission = sermon?.sourceType == SermonSource.userSubmission;
    final audioSlot = ref.watch(uploadSlotProvider('audio:${widget.id}'));
    final coverSlot = ref.watch(uploadSlotProvider('cover:${widget.id}'));

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (sermon != null) ...[
            Row(
              children: [
                ContentStatusChip(status: sermon.status),
                const SizedBox(width: AppSpacing.xs),
                if (isSubmission)
                  const Chip(
                    label: Text('COMMUNITY RECORDING'),
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                if (sermon.publishedAt != null)
                  Text(
                    'Published ${formatShortDate(sermon.publishedAt)}',
                    style: context.text.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ActionError(state: action),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *'),
            validator: Validators.title,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _speaker,
            decoration: const InputDecoration(labelText: 'Speaker *'),
            validator: (v) =>
                Validators.required(v, field: 'Speaker') ??
                Validators.optionalShort(v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _scripture,
            decoration: const InputDecoration(
              labelText: 'Scripture reference',
              hintText: 'John 15:1–8',
            ),
            validator: Validators.optionalShort,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _quote,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Key verse text (optional)',
              alignLabelWithHint: true,
            ),
            validator: (v) => Validators.maxLength(v, 400),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: SermonCategories.all.contains(_category)
                ? _category
                : null,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in SermonCategories.all)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            validator: Validators.description,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _featured,
            onChanged: (v) => setState(() => _featured = v),
            title: const Text('Feature as “Sermon of the week”'),
          ),
          FilledButton(
            onPressed: action.isLoading ? null : _save,
            child: Text(created ? 'Save changes' : 'Create draft'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text('Audio', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          if (!created)
            Text(
              'Create the draft first, then upload audio.',
              style: context.text.bodySmall,
            )
          else if (isSubmission)
            Text(
              'Audio comes from the reviewed community recording and cannot be replaced here.',
              style: context.text.bodySmall,
            )
          else ...[
            if (sermon.hasAudio) ...[
              PreviewPlayer(
                source: StorageSource(sermon.storagePath!),
                label: 'Current audio',
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${formatDuration(Duration(seconds: sermon.durationSeconds))} · ${formatBytes(sermon.audioSizeBytes)}',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            UploadProgressCard(
              label: audioSlot.fileName ?? 'Audio',
              progress: audioSlot.progress,
              error: audioSlot.error?.message,
              onRetry: () => ref
                  .read(uploadSlotProvider('audio:${widget.id}').notifier)
                  .retry(),
              onCancel: () => ref
                  .read(uploadSlotProvider('audio:${widget.id}').notifier)
                  .cancel(),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: audioSlot.busy ? null : _pickAudio,
              icon: const Icon(Icons.audio_file_outlined),
              label: Text(
                sermon.hasAudio ? 'Replace audio' : 'Choose audio file',
              ),
            ),
            Text(
              'MP3, M4A, AAC, WAV or OGG · up to 200 MB',
              style: context.text.bodySmall,
            ),
          ],
          if (created) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Cover image', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            if (sermon.coverStoragePath != null)
              ClipRRect(
                borderRadius: AppRadii.card,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: StorageImage(path: sermon.coverStoragePath),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            UploadProgressCard(
              label: coverSlot.fileName ?? 'Cover',
              progress: coverSlot.progress,
              error: coverSlot.error?.message,
              onRetry: () => ref
                  .read(uploadSlotProvider('cover:${widget.id}').notifier)
                  .retry(),
            ),
            OutlinedButton.icon(
              onPressed: coverSlot.busy ? null : _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                sermon.coverStoragePath != null
                    ? 'Replace cover'
                    : 'Add cover image',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Text('Publication', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            LifecycleActions(
              status: sermon.status,
              busy: action.isLoading,
              entityLabel: 'sermon',
              onChange: (next) async {
                await ref
                    .read(adminActionProvider(_actionKey).notifier)
                    .run(
                      (admin) => ref
                          .read(adminSermonRepositoryProvider)
                          .setStatus(sermon, next, admin),
                    );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
