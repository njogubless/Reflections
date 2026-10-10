import 'recording_submission.dart';

/// A completed, on-device recording that has not yet been submitted.
class RecordingDraft {
  const RecordingDraft({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const SermonMetadata(title: ''),
    this.resubmissionOf,
  });

  /// Also used as the Firestore recording ID on submission, which makes
  /// retried submissions idempotent.
  final String id;
  final String filePath;
  final Duration duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SermonMetadata metadata;

  /// Set when re-recording audio for a submission returned with changes.
  final String? resubmissionOf;

  String get recordingId => resubmissionOf ?? id;

  RecordingDraft copyWith({SermonMetadata? metadata, DateTime? updatedAt}) =>
      RecordingDraft(
        id: id,
        filePath: filePath,
        duration: duration,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        metadata: metadata ?? this.metadata,
        resubmissionOf: resubmissionOf,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'durationMs': duration.inMilliseconds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'metadata': metadata.toJson(),
    'resubmissionOf': resubmissionOf,
  };

  factory RecordingDraft.fromJson(Map<String, dynamic> j) => RecordingDraft(
    id: j['id'] as String,
    filePath: j['filePath'] as String,
    duration: Duration(milliseconds: (j['durationMs'] as num).toInt()),
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    metadata: SermonMetadata.fromJson(
      (j['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    resubmissionOf: j['resubmissionOf'] as String?,
  );
}
