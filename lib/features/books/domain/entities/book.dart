import '../../../../core/domain/content_status.dart';

/// Only formats the reader actually renders. EPUB is intentionally absent.
enum BookFormat {
  pdf('pdf', 'application/pdf', 'PDF');

  const BookFormat(this.wire, this.mimeType, this.label);
  final String wire;
  final String mimeType;
  final String label;

  static BookFormat? fromWire(Object? v) {
    for (final f in values) {
      if (f.wire == v) return f;
    }
    return null;
  }
}

abstract final class BookLimits {
  static const maxBytes = 50 * 1024 * 1024;
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.category,
    required this.status,
    this.coverStoragePath,
    this.fileStoragePath,
    this.fileFormat,
    this.fileSizeBytes = 0,
    this.uploadedBy,
    this.featured = false,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String category;
  final ContentStatus status;
  final String? coverStoragePath;
  final String? fileStoragePath;
  final BookFormat? fileFormat;
  final int fileSizeBytes;
  final String? uploadedBy;
  final bool featured;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReadable => fileStoragePath != null && fileFormat != null;
}
