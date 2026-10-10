import 'recording_status.dart';

/// Hard limit for user recordings (CLAUDE.md §3.1).
abstract final class RecordingLimits {
  static const maxDuration = Duration(seconds: 1200);

  /// Matches storage.rules. 20 min at 64 kbps mono AAC ≈ 9.6 MB.
  static const maxBytes = 25 * 1024 * 1024;

  static const warnRemaining = Duration(minutes: 2);
}

class SermonMetadata {
  const SermonMetadata({
    required this.title,
    this.description = '',
    this.speakerName = '',
    this.scriptureReference = '',
  });

  final String title;
  final String description;
  final String speakerName;
  final String scriptureReference;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'speakerName': speakerName,
    'scriptureReference': scriptureReference,
  };

  factory SermonMetadata.fromJson(Map<String, dynamic> j) => SermonMetadata(
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    speakerName: j['speakerName'] as String? ?? '',
    scriptureReference: j['scriptureReference'] as String? ?? '',
  );
}

class RecordingSubmission {
  const RecordingSubmission({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.metadata,
    required this.storagePath,
    required this.durationSeconds,
    required this.status,
    this.sizeBytes = 0,
    this.reviewFeedback,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    this.submittedAt,
    this.publishedSermonId,
    this.revision = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String ownerName;
  final SermonMetadata metadata;
  final String storagePath;
  final int durationSeconds;
  final int sizeBytes;
  final RecordingStatus status;
  final String? reviewFeedback;
  final String? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final DateTime? submittedAt;
  final String? publishedSermonId;
  final int revision;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get title => metadata.title;

  /// Deterministic ID of the sermon created on publication (idempotency).
  static String sermonIdFor(String recordingId) => 'rec_$recordingId';

  static String storagePathFor(String ownerUid, String recordingId) =>
      'recordings/$ownerUid/$recordingId/audio';
}
