/// Lifecycle of a user-recorded sermon. `draft` exists only on-device.
///
/// draft -> submitted -> under_review -> approved -> published
///                        under_review -> changes_requested -> submitted
///                        under_review -> rejected
///
/// Mirrored by `recordingTransitionAllowed` in firestore.rules.
enum RecordingStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  underReview('under_review', 'In review'),
  changesRequested('changes_requested', 'Changes requested'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  published('published', 'Published');

  const RecordingStatus(this.wire, this.label);

  final String wire;
  final String label;

  static RecordingStatus fromWire(Object? v) => values.firstWhere(
    (s) => s.wire == v,
    orElse: () => RecordingStatus.submitted,
  );

  bool get isTerminal => this == rejected || this == published;

  /// Whether the owner can currently edit and resubmit.
  bool get ownerCanResubmit => this == changesRequested;
}

enum RecordingActor { owner, admin }

abstract final class RecordingTransitions {
  static const _owner = {
    RecordingStatus.draft: {RecordingStatus.submitted},
    RecordingStatus.changesRequested: {RecordingStatus.submitted},
  };

  static const _admin = {
    RecordingStatus.submitted: {RecordingStatus.underReview},
    RecordingStatus.underReview: {
      RecordingStatus.approved,
      RecordingStatus.rejected,
      RecordingStatus.changesRequested,
    },
    RecordingStatus.approved: {RecordingStatus.published},
  };

  static bool canTransition(
    RecordingStatus from,
    RecordingStatus to,
    RecordingActor actor,
  ) {
    final table = actor == RecordingActor.owner ? _owner : _admin;
    return table[from]?.contains(to) ?? false;
  }

  /// Rejection and change requests must explain why.
  static bool requiresFeedback(RecordingStatus to) =>
      to == RecordingStatus.rejected || to == RecordingStatus.changesRequested;
}
