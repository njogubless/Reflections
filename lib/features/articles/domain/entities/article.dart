import '../../../../core/domain/content_status.dart';

/// Structured article content. No HTML is stored or rendered.
enum ArticleBlockType {
  paragraph('p'),
  heading('h'),
  quote('q'),
  scripture('s');

  const ArticleBlockType(this.wire);
  final String wire;

  static ArticleBlockType fromWire(Object? v) => values.firstWhere(
    (t) => t.wire == v,
    orElse: () => ArticleBlockType.paragraph,
  );
}

class ArticleBlock {
  const ArticleBlock(this.type, this.text, {this.reference});

  final ArticleBlockType type;
  final String text;

  /// Scripture reference for [ArticleBlockType.scripture] blocks.
  final String? reference;

  Map<String, dynamic> toMap() => {
    't': type.wire,
    'x': text,
    if (reference != null) 'r': reference,
  };

  factory ArticleBlock.fromMap(Map<String, dynamic> m) => ArticleBlock(
    ArticleBlockType.fromWire(m['t']),
    m['x'] as String? ?? '',
    reference: m['r'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is ArticleBlock &&
      other.type == type &&
      other.text == text &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(type, text, reference);
}

/// Converts the constrained authoring syntax to blocks and back.
///
///   ## Heading
///   > Quoted text
///   >> Scripture text — Reference
///   Plain paragraphs separated by blank lines.
abstract final class ArticleBodyCodec {
  static List<ArticleBlock> parse(String source) {
    final blocks = <ArticleBlock>[];
    final chunks = source.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    for (final raw in chunks) {
      final chunk = raw.trim();
      if (chunk.isEmpty) continue;
      if (chunk.startsWith('## ')) {
        blocks.add(
          ArticleBlock(ArticleBlockType.heading, chunk.substring(3).trim()),
        );
      } else if (chunk.startsWith('>>')) {
        final body = _stripPrefix(chunk, '>>');
        final dash = body.lastIndexOf(' — ');
        if (dash > 0) {
          blocks.add(
            ArticleBlock(
              ArticleBlockType.scripture,
              body.substring(0, dash).trim(),
              reference: body.substring(dash + 3).trim(),
            ),
          );
        } else {
          blocks.add(ArticleBlock(ArticleBlockType.scripture, body));
        }
      } else if (chunk.startsWith('>')) {
        blocks.add(
          ArticleBlock(ArticleBlockType.quote, _stripPrefix(chunk, '>')),
        );
      } else {
        blocks.add(
          ArticleBlock(
            ArticleBlockType.paragraph,
            chunk.split('\n').map((l) => l.trim()).join(' '),
          ),
        );
      }
    }
    return blocks;
  }

  static String _stripPrefix(String chunk, String prefix) => chunk
      .split('\n')
      .map(
        (l) => l.trimLeft().startsWith(prefix)
            ? l.trimLeft().substring(prefix.length)
            : l,
      )
      .map((l) => l.trim())
      .join(' ')
      .trim();

  static String serialize(List<ArticleBlock> blocks) => blocks
      .map((b) {
        return switch (b.type) {
          ArticleBlockType.heading => '## ${b.text}',
          ArticleBlockType.quote => '> ${b.text}',
          ArticleBlockType.scripture =>
            b.reference == null
                ? '>> ${b.text}'
                : '>> ${b.text} — ${b.reference}',
          ArticleBlockType.paragraph => b.text,
        };
      })
      .join('\n\n');

  /// ~200 words per minute.
  static int readMinutes(List<ArticleBlock> blocks) {
    final words = blocks.fold<int>(
      0,
      (n, b) =>
          n + b.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );
    return words == 0 ? 0 : (words / 200).ceil();
  }
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.blocks,
    required this.category,
    required this.status,
    required this.authorName,
    this.authorId,
    this.coverStoragePath,
    this.tags = const [],
    this.readMinutes = 0,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String summary;
  final List<ArticleBlock> blocks;
  final String category;
  final ContentStatus status;
  final String? authorId;
  final String authorName;
  final String? coverStoragePath;
  final List<String> tags;
  final int readMinutes;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
