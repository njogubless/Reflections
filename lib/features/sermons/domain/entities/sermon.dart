import '../../../../core/domain/content_status.dart';

/// Discriminates admin-uploaded audio from published user recordings.
/// Immutable after creation (enforced in firestore.rules).
enum SermonSource {
  adminPublished('admin_published'),
  userSubmission('user_submission');

  const SermonSource(this.wire);
  final String wire;

  static SermonSource fromWire(Object? v) => v == 'user_submission'
      ? SermonSource.userSubmission
      : SermonSource.adminPublished;
}

abstract final class SermonCategories {
  static const all = [
    'Faith & Prayer',
    'Grace',
    'Expository',
    'Pastoral',
    'Sunday Homily',
    'Meditative',
    'Devotional',
    'Teaching',
  ];
}

class Sermon {
  const Sermon({
    required this.id,
    required this.title,
    required this.description,
    required this.speakerName,
    required this.scriptureReference,
    required this.category,
    required this.sourceType,
    required this.status,
    required this.storagePath,
    required this.durationSeconds,
    this.coverStoragePath,
    this.scriptureQuote,
    this.uploadedBy,
    this.originRecordingId,
    this.featured = false,
    this.audioSizeBytes = 0,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String speakerName;
  final String scriptureReference;

  /// Optional key verse text shown as a quote on cards and the player.
  final String? scriptureQuote;
  final String category;
  final SermonSource sourceType;
  final ContentStatus status;

  /// Storage path of the audio object (never a permanent download URL).
  final String? storagePath;
  final String? coverStoragePath;
  final int durationSeconds;
  final int audioSizeBytes;
  final String? uploadedBy;
  final String? originRecordingId;
  final bool featured;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasAudio => storagePath != null && storagePath!.isNotEmpty;

  Sermon copyWith({
    String? title,
    String? description,
    String? speakerName,
    String? scriptureReference,
    String? scriptureQuote,
    String? category,
    ContentStatus? status,
    String? storagePath,
    String? coverStoragePath,
    int? durationSeconds,
    int? audioSizeBytes,
    bool? featured,
  }) => Sermon(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    speakerName: speakerName ?? this.speakerName,
    scriptureReference: scriptureReference ?? this.scriptureReference,
    scriptureQuote: scriptureQuote ?? this.scriptureQuote,
    category: category ?? this.category,
    sourceType: sourceType,
    status: status ?? this.status,
    storagePath: storagePath ?? this.storagePath,
    coverStoragePath: coverStoragePath ?? this.coverStoragePath,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    audioSizeBytes: audioSizeBytes ?? this.audioSizeBytes,
    uploadedBy: uploadedBy,
    originRecordingId: originRecordingId,
    featured: featured ?? this.featured,
    publishedAt: publishedAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
