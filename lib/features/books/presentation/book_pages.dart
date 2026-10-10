import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/media_storage.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_image.dart';
import '../domain/entities/book.dart';
import 'book_providers.dart';

class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => context.push(Routes.book(book.id)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.base),
          child: SizedBox(
            width: 72,
            height: 104,
            child: StorageImage(
              path: book.coverStoragePath,
              fallbackIcon: Icons.menu_book,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.category.isNotEmpty)
                Text(
                  book.category.toUpperCase(),
                  style: context.devotionText.overline,
                ),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall,
              ),
              Text(book.author, style: context.text.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                book.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BookDetailPage extends ConsumerWidget {
  const BookDetailPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookDetailProvider(bookId));
    final lastPage = ref.watch(lastPageProvider(bookId)).value ?? 1;
    return Scaffold(
      appBar: AppBar(),
      body: AsyncValueView(
        value: book,
        onRetry: () => ref.invalidate(bookDetailProvider(bookId)),
        data: (b) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: AppRadii.card,
                child: SizedBox(
                  width: 180,
                  height: 260,
                  child: StorageImage(
                    path: b.coverStoragePath,
                    fallbackIcon: Icons.menu_book,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (b.category.isNotEmpty)
              Text(
                b.category.toUpperCase(),
                textAlign: TextAlign.center,
                style: context.devotionText.overline,
              ),
            Text(
              b.title,
              textAlign: TextAlign.center,
              style: context.text.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              b.author,
              textAlign: TextAlign.center,
              style: context.text.labelLarge?.copyWith(
                color: AppColors.goldDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                if (b.fileFormat != null) b.fileFormat!.label,
                if (b.fileSizeBytes > 0) formatBytes(b.fileSizeBytes),
                if (b.publishedAt != null)
                  'Published ${formatShortDate(b.publishedAt)}',
              ].join(' · '),
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: b.isReadable
                  ? () => context.push(Routes.bookReader(b.id))
                  : null,
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              label: Text(
                lastPage > 1
                    ? 'Continue reading (page $lastPage)'
                    : 'Read book',
              ),
            ),
            if (!b.isReadable)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'This book’s file is not available yet.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(b.description, style: context.text.bodyLarge),
          ],
        ),
      ),
    );
  }
}

final _bookUrlProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  bookId,
) async {
  final book = await ref.watch(bookDetailProvider(bookId).future);
  if (!book.isReadable) throw StateError('No document');
  return ref.watch(mediaStorageProvider).downloadUrl(book.fileStoragePath!);
});

/// PDF reader (the only supported book format).
class BookReaderPage extends ConsumerStatefulWidget {
  const BookReaderPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends ConsumerState<BookReaderPage> {
  final _controller = PdfViewerController();
  int? _page;
  int? _pageCount;

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookDetailProvider(widget.bookId));
    final url = ref.watch(_bookUrlProvider(widget.bookId));
    final initial = ref.watch(lastPageProvider(widget.bookId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          book.value?.title ?? 'Reader',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: _pageCount == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Text(
                  'Page ${_page ?? 1} of $_pageCount',
                  style: context.text.bodySmall,
                ),
              ),
      ),
      body: switch ((url, initial)) {
        (AsyncData(value: final u), AsyncData(value: final start)) =>
          PdfViewer.uri(
            Uri.parse(u),
            controller: _controller,
            initialPageNumber: start,
            params: PdfViewerParams(
              backgroundColor: AppColors.surfaceLow,
              onViewerReady: (doc, _) =>
                  setState(() => _pageCount = doc.pages.length),
              onPageChanged: (page) {
                if (page == null) return;
                setState(() => _page = page);
                ref
                    .read(readingProgressStoreProvider)
                    .save(widget.bookId, page);
              },
              loadingBannerBuilder: (context, done, total) => LoadingView(
                label: total == null
                    ? 'Opening book…'
                    : 'Downloading ${(done * 100 / total).round()}%',
              ),
              errorBannerBuilder: (context, error, _, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(_bookUrlProvider(widget.bookId)),
              ),
            ),
          ),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(_bookUrlProvider(widget.bookId)),
        ),
        _ => const LoadingView(label: 'Opening book…'),
      },
    );
  }
}
