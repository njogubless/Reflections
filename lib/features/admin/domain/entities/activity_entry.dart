class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.summary,
    this.createdAt,
  });

  final String id;
  final String actorUid;
  final String actorName;

  /// e.g. `sermon.published`, `recording.approved`, `answer.published`.
  final String action;
  final String entityType;
  final String entityId;
  final String summary;
  final DateTime? createdAt;
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.publishedSermons,
    required this.pendingReviews,
    required this.publishedBooks,
    required this.publishedArticles,
    required this.unansweredQuestions,
    required this.draftItems,
  });

  final int publishedSermons;
  final int pendingReviews;
  final int publishedBooks;
  final int publishedArticles;
  final int unansweredQuestions;

  /// Admin drafts across sermons, books and articles.
  final int draftItems;
}
