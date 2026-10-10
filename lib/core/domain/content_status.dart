/// Publication lifecycle shared by admin-managed sermons, books and articles.
enum ContentStatus {
  draft('draft', 'Draft'),
  published('published', 'Published'),
  unpublished('unpublished', 'Unpublished'),
  archived('archived', 'Archived');

  const ContentStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ContentStatus fromWire(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => ContentStatus.draft);

  bool get isPublic => this == ContentStatus.published;

  /// Admin lifecycle transitions (mirrored in firestore.rules).
  Set<ContentStatus> get allowedNext => switch (this) {
    draft => {published, archived},
    published => {unpublished, archived},
    unpublished => {published, draft, archived},
    archived => {draft},
  };

  bool canTransitionTo(ContentStatus next) => allowedNext.contains(next);
}
