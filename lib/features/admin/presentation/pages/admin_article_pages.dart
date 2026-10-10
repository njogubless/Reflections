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
import '../../../../core/widgets/upload_progress_card.dart';
import '../../../articles/data/article_data.dart';
import '../../../articles/domain/entities/article.dart';
import '../../../articles/presentation/article_pages.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class AdminArticlesPage extends ConsumerStatefulWidget {
  const AdminArticlesPage({super.key});

  @override
  ConsumerState<AdminArticlesPage> createState() => _AdminArticlesPageState();
}

class _AdminArticlesPageState extends ConsumerState<AdminArticlesPage> {
  ContentStatus? _status;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminArticleListProvider(_status));
    final notifier = ref.read(adminArticleListProvider(_status).notifier);
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Articles')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => context.push(Routes.adminArticleNew),
          icon: const Icon(Icons.edit_note),
          label: const Text('Write article'),
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
              PagedSliverList<Article>(
                state: list,
                onLoadMore: notifier.loadMore,
                onRetry: notifier.refresh,
                empty: const EmptyView(
                  icon: Icons.article_outlined,
                  title: 'No articles here',
                ),
                itemBuilder: (context, a) => AppCard(
                  onTap: () => context.push(Routes.adminArticleEdit(a.id)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: context.text.headlineSmall),
                            Text(
                              '${a.category} · ${a.authorName} · updated ${formatRelative(a.updatedAt)}',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ContentStatusChip(status: a.status),
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

class AdminArticleEditorPage extends ConsumerStatefulWidget {
  const AdminArticleEditorPage({super.key, this.articleId});

  final String? articleId;

  @override
  ConsumerState<AdminArticleEditorPage> createState() =>
      _AdminArticleEditorPageState();
}

class _AdminArticleEditorPageState
    extends ConsumerState<AdminArticleEditorPage> {
  late final String _id =
      widget.articleId ?? ref.read(adminArticleRepositoryProvider).newId();
  late bool _isNew = widget.articleId == null;

  @override
  Widget build(BuildContext context) {
    if (_isNew) {
      return AdminGate(
        child: _ArticleEditor(
          id: _id,
          initial: null,
          onCreated: () => setState(() => _isNew = false),
        ),
      );
    }
    final article = ref.watch(adminArticleProvider(_id));
    return AdminGate(
      child: article.when(
        data: (a) => a == null
            ? const Scaffold(
                body: EmptyView(
                  icon: Icons.search_off,
                  title: 'Article not found',
                ),
              )
            : _ArticleEditor(id: _id, initial: a),
        loading: () => const Scaffold(body: LoadingView()),
        error: (e, _) => Scaffold(
          body: ErrorView(
            error: e,
            onRetry: () => ref.invalidate(adminArticleProvider(_id)),
          ),
        ),
      ),
    );
  }
}

class _ArticleEditor extends ConsumerStatefulWidget {
  const _ArticleEditor({
    required this.id,
    required this.initial,
    this.onCreated,
  });

  final String id;
  final Article? initial;
  final VoidCallback? onCreated;

  @override
  ConsumerState<_ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends ConsumerState<_ArticleEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _summary = TextEditingController(text: widget.initial?.summary);
  late final _author = TextEditingController(
    text:
        widget.initial?.authorName ??
        ref.read(currentUserProvider)?.displayName,
  );
  late final _tags = TextEditingController(
    text: widget.initial?.tags.join(', '),
  );
  late final _body = TextEditingController(
    text: widget.initial == null
        ? ''
        : ArticleBodyCodec.serialize(widget.initial!.blocks),
  );
  late String _category = widget.initial?.category.isNotEmpty == true
      ? widget.initial!.category
      : ArticleCategories.all.first;
  bool _dirty = false;

  String get _key => 'article:${widget.id}';

  @override
  void dispose() {
    for (final c in [_title, _summary, _author, _tags, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  Article _build() => Article(
    id: widget.id,
    title: _title.text.trim(),
    summary: _summary.text.trim(),
    blocks: ArticleBodyCodec.parse(_body.text),
    category: _category,
    status: widget.initial?.status ?? ContentStatus.draft,
    authorId: widget.initial?.authorId,
    authorName: _author.text.trim(),
    coverStoragePath: widget.initial?.coverStoragePath,
    tags: _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(),
    publishedAt: widget.initial?.publishedAt,
  );

  Future<bool> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return false;
    final isNew = widget.initial == null;
    final ok = await ref
        .read(adminActionProvider(_key).notifier)
        .run(
          (admin) => ref
              .read(adminArticleRepositoryProvider)
              .save(_build(), admin, isNew: isNew),
        );
    if (ok && mounted) {
      setState(() => _dirty = false);
      showAppSnack(context, isNew ? 'Draft saved.' : 'Changes saved.');
      widget.onCreated?.call();
    }
    return ok;
  }

  Future<void> _pickCover() async {
    final slot = ref.read(
      uploadSlotProvider('articlecover:${widget.id}').notifier,
    );
    try {
      final picked = await pickLocalFile(PickKind.image);
      if (picked == null) return;
      final repo = ref.read(adminArticleRepositoryProvider);
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

  void _preview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Preview')),
          body: ArticleView(article: _build()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(adminActionProvider(_key));
    final article = widget.initial;
    final cover = ref.watch(uploadSlotProvider('articlecover:${widget.id}'));
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(article == null ? 'New Article' : 'Edit Article'),
          actions: [
            IconButton(
              tooltip: 'Preview',
              onPressed: _preview,
              icon: const Icon(Icons.visibility_outlined),
            ),
          ],
        ),
        body: Form(
          key: _form,
          onChanged: () => _dirty = true,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              if (article != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: ContentStatusChip(status: article.status),
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
                controller: _summary,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  alignLabelWithHint: true,
                ),
                validator: (v) => Validators.maxLength(v, 500),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in ArticleCategories.all)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() {
                        _category = v ?? _category;
                        _dirty = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _author,
                      decoration: const InputDecoration(
                        labelText: 'Author name',
                      ),
                      validator: Validators.optionalShort,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'grace, prayer',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: AppColors.recessed,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'Formatting: blank line between paragraphs · “## ” heading · “> ” quote · “>> text — Reference” scripture. No HTML.',
                  style: context.text.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _body,
                minLines: 12,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Body *',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    Validators.required(v, field: 'Body') ??
                    Validators.maxLength(v, Limits.articleBodyMax),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Preview'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: action.isLoading ? null : _save,
                      child: Text(article == null ? 'Save draft' : 'Save'),
                    ),
                  ),
                ],
              ),
              if (article != null) ...[
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text('Cover image', style: context.text.headlineSmall),
                UploadProgressCard(
                  label: cover.fileName ?? 'Cover',
                  progress: cover.progress,
                  error: cover.error?.message,
                  onRetry: () => ref
                      .read(
                        uploadSlotProvider(
                          'articlecover:${widget.id}',
                        ).notifier,
                      )
                      .retry(),
                ),
                OutlinedButton.icon(
                  onPressed: cover.busy ? null : _pickCover,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    article.coverStoragePath != null
                        ? 'Replace cover'
                        : 'Add cover',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Publication', style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                if (_dirty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      'Save your changes before changing publication status.',
                      style: context.text.bodySmall?.copyWith(
                        color: AppColors.changes,
                      ),
                    ),
                  ),
                LifecycleActions(
                  status: article.status,
                  busy: action.isLoading || _dirty,
                  entityLabel: 'article',
                  onChange: (next) async {
                    await ref
                        .read(adminActionProvider(_key).notifier)
                        .run(
                          (admin) => ref
                              .read(adminArticleRepositoryProvider)
                              .setStatus(article, next, admin),
                        );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
