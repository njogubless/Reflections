enum NotificationType {
  recordingSubmitted('recording_submitted'),
  recordingApproved('recording_approved'),
  recordingRejected('recording_rejected'),
  recordingChangesRequested('recording_changes_requested'),
  recordingPublished('recording_published'),
  questionAnswered('question_answered'),
  newSubmissionForReview('new_submission_for_review'),
  other('other');

  const NotificationType(this.wire);
  final String wire;

  static NotificationType fromWire(Object? v) => values.firstWhere(
    (t) => t.wire == v,
    orElse: () => NotificationType.other,
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.relatedEntityId,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedEntityId;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;
}
