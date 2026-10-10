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
import '../../../books/domain/entities/book.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class AdminBooksPage extends ConsumerStatefulWidget {
  const AdminBooksPage({super.key});

  @override
  ConsumerState<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends ConsumerState<AdminBooksPage> {
  ContentStatus? _status;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminBookListProvider(_status));
    final notifier = ref.read(adminBookListProvider(_status).notifier);
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Books')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => context.push(Routes.adminBookNew),
          icon: const Icon(Icons.add),
          label: const Text('Add book'),
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
              PagedSliverList<Book>(
                state: list,
                onLoadMore: notifier.loadMore,
                onRetry: notifier.refresh,
                empty: const EmptyView(
                  icon: Icons.menu_book_outlined,
                  title: 'No books here',
                ),
                itemBuilder: (context, b) => AppCard(
                  onTap: () => context.push(Routes.adminBookEdit(b.id)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title, style: context.text.headlineSmall),
                            Text(
                              '${b.author} · ${b.isReadable ? '${b.fileFormat!.label}, ${formatBytes(b.fileSizeBytes)}' : 'no file yet'}',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ContentStatusChip(status: b.status),
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

class AdminBookEditorPage extends ConsumerStatefulWidget {
  const AdminBookEditorPage({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<AdminBookEditorPage> createState() =>
      _AdminBookEditorPageState();
}

class _AdminBookEditorPageState extends ConsumerState<AdminBookEditorPage> {
  late final String _id =
      widget.bookId ?? ref.read(adminBookRepositoryProvider).newId();
  late bool _isNew = widget.bookId == null;

  @override
  Widget build(BuildContext context) {
    if (_isNew) {
      return AdminGate(
        child: Scaffold(
          appBar: AppBar(title: const Text('New Book')),
          body: _BookForm(
            id: _id,
            initial: null,
            onCreated: () => setState(() => _isNew = false),
          ),
        ),
      );
    }
    final book = ref.watch(adminBookProvider(_id));
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Book')),
        body: AsyncValueView(
          value: book,
          onRetry: () => ref.invalidate(adminBookProvider(_id)),
          data: (b) => b == null
              ? const EmptyView(icon: Icons.search_off, title: 'Book not found')
              : _BookForm(id: _id, initial: b),
        ),
      ),
    );
  }
}

class _BookForm extends ConsumerStatefulWidget {
  const _BookForm({required this.id, required this.initial, this.onCreated});

  final String id;
  final Book? initial;
  final VoidCallback? onCreated;

  @override
  ConsumerState<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends ConsumerState<_BookForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _author = TextEditingController(text: widget.initial?.author);
  late final _category = TextEditingController(text: widget.initial?.category);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late bool _featured = widget.initial?.featured ?? false;

  String get _key => 'book:${widget.id}';

  @override
  void dispose() {
    for (final c in [_title, _author, _category, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final i = widget.initial;
    final book = Book(
      id: widget.id,
      title: _title.text,
      author: _author.text,
      description: _description.text,
      category: _category.text,
      status: i?.status ?? ContentStatus.draft,
      featured: _featured,
    );
    final ok = await ref
        .read(adminActionProvider(_key).notifier)
        .run(
          (admin) => ref
              .read(adminBookRepositoryProvider)
              .saveMetadata(book, admin, isNew: i == null),
        );
    if (ok && mounted) {
      showAppSnack(
        context,
        i == null ? 'Draft created. Now upload the PDF.' : 'Changes saved.',
      );
      widget.onCreated?.call();
    }
  }

  Future<void> _pickPdf() async {
    final slot = ref.read(uploadSlotProvider('doc:${widget.id}').notifier);
    try {
      final picked = await pickLocalFile(PickKind.pdf);
      if (picked == null) return;
      final repo = ref.read(adminBookRepositoryProvider);
      await slot.run(
        fileName: picked.name,
        start: () => repo.uploadDocument(widget.id, picked.file),
        attach: () =>
            repo.attachDocument(widget.id, sizeBytes: picked.sizeBytes),
      );
    } on AppException catch (e) {
      slot.fail(e);
    }
  }

  Future<void> _pickCover() async {
    final slot = ref.read(
      uploadSlotProvider('bookcover:${widget.id}').notifier,
    );
    try {
      final picked = await pickLocalFile(PickKind.image);
      if (picked == null) return;
      final repo = ref.read(adminBookRepositoryProvider);
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
    final action = ref.watch(adminActionProvider(_key));
    final book = widget.initial;
    final doc = ref.watch(uploadSlotProvider('doc:${widget.id}'));
    final cover = ref.watch(uploadSlotProvider('bookcover:${widget.id}'));
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (book != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ContentStatusChip(status: book.status),
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
            controller: _author,
            decoration: const InputDecoration(labelText: 'Author *'),
            validator: (v) =>
                Validators.required(v, field: 'Author') ??
                Validators.optionalShort(v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'e.g. Devotional',
            ),
            validator: Validators.optionalShort,
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
            title: const Text('Feature in Reading Spotlight'),
          ),
          FilledButton(
            onPressed: action.isLoading ? null : _save,
            child: Text(book == null ? 'Create draft' : 'Save changes'),
          ),
          if (book != null) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Text('Book file (PDF)', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              book.isReadable
                  ? 'Current file: ${book.fileFormat!.label}, ${formatBytes(book.fileSizeBytes)}'
                  : 'No file uploaded yet. Only PDF is supported by the reader.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            UploadProgressCard(
              label: doc.fileName ?? 'PDF',
              progress: doc.progress,
              error: doc.error?.message,
              onRetry: () => ref
                  .read(uploadSlotProvider('doc:${widget.id}').notifier)
                  .retry(),
              onCancel: () => ref
                  .read(uploadSlotProvider('doc:${widget.id}').notifier)
                  .cancel(),
            ),
            OutlinedButton.icon(
              onPressed: doc.busy ? null : _pickPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(book.isReadable ? 'Replace PDF' : 'Choose PDF'),
            ),
            Text('PDF up to 50 MB', style: context.text.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            Text('Cover image', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            if (book.coverStoragePath != null)
              Center(
                child: ClipRRect(
                  borderRadius: AppRadii.control,
                  child: SizedBox(
                    width: 120,
                    height: 170,
                    child: StorageImage(path: book.coverStoragePath),
                  ),
                ),
              ),
            UploadProgressCard(
              label: cover.fileName ?? 'Cover',
              progress: cover.progress,
              error: cover.error?.message,
              onRetry: () => ref
                  .read(uploadSlotProvider('bookcover:${widget.id}').notifier)
                  .retry(),
            ),
            OutlinedButton.icon(
              onPressed: cover.busy ? null : _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                book.coverStoragePath != null ? 'Replace cover' : 'Add cover',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Text('Publication', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            LifecycleActions(
              status: book.status,
              busy: action.isLoading,
              entityLabel: 'book',
              onChange: (next) async {
                await ref
                    .read(adminActionProvider(_key).notifier)
                    .run(
                      (admin) => ref
                          .read(adminBookRepositoryProvider)
                          .setStatus(book, next, admin),
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
