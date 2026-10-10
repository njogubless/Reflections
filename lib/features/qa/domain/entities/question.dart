enum QuestionStatus {
  open('open', 'Awaiting answer'),
  answered('answered', 'Answered'),
  closed('closed', 'Closed');

  const QuestionStatus(this.wire, this.label);
  final String wire;
  final String label;

  static QuestionStatus fromWire(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => QuestionStatus.open);
}

enum QuestionVisibility {
  /// Only the asker and administrators can read it.
  private('private'),

  /// Once answered, shown to the community without the asker's identity.
  public('public');

  const QuestionVisibility(this.wire);
  final String wire;

  static QuestionVisibility fromWire(Object? v) =>
      v == 'public' ? QuestionVisibility.public : QuestionVisibility.private;
}

abstract final class QuestionCategories {
  static const all = [
    'Doctrine',
    'Scripture',
    'Prayer',
    'Spiritual formation',
    'Church life',
    'Family & relationships',
    'Other',
  ];
}

class Question {
  const Question({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.body,
    required this.category,
    required this.visibility,
    required this.status,
    this.scriptureReference = '',
    this.answeredAt,
    this.answeredByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String title;
  final String body;
  final String category;
  final String scriptureReference;
  final QuestionVisibility visibility;
  final QuestionStatus status;
  final DateTime? answeredAt;
  final String? answeredByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class NewQuestion {
  const NewQuestion({
    required this.title,
    required this.body,
    required this.category,
    required this.visibility,
    this.scriptureReference = '',
  });

  final String title;
  final String body;
  final String category;
  final String scriptureReference;
  final QuestionVisibility visibility;
}

enum AnswerStatus {
  draft('draft'),
  published('published');

  const AnswerStatus(this.wire);
  final String wire;

  static AnswerStatus fromWire(Object? v) =>
      v == 'published' ? AnswerStatus.published : AnswerStatus.draft;
}

/// The single official administrator answer (`questions/{id}/answers/official`).
class OfficialAnswer {
  const OfficialAnswer({
    required this.questionId,
    required this.adminUid,
    required this.adminName,
    required this.body,
    required this.status,
    this.publishedAt,
    this.updatedAt,
  });

  final String questionId;
  final String adminUid;
  final String adminName;
  final String body;
  final AnswerStatus status;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  bool get isPublished => status == AnswerStatus.published;
}
