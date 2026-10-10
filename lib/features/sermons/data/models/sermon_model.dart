import '../../../../core/domain/content_status.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/sermon.dart';

abstract final class SermonModel {
  static const collection = 'sermons';

  static Sermon fromMap(String id, Map<String, dynamic> d) => Sermon(
    id: id,
    title: readString(d, 'title'),
    description: readString(d, 'description'),
    speakerName: readString(d, 'speakerName'),
    scriptureReference: readString(d, 'scriptureReference'),
    scriptureQuote: readOptionalString(d, 'scriptureQuote'),
    category: readString(d, 'category'),
    sourceType: SermonSource.fromWire(d['sourceType']),
    status: ContentStatus.fromWire(d['status']),
    storagePath: readOptionalString(d, 'storagePath'),
    coverStoragePath: readOptionalString(d, 'coverStoragePath'),
    durationSeconds: readInt(d, 'durationSeconds'),
    audioSizeBytes: readInt(d, 'audioSizeBytes'),
    uploadedBy: readOptionalString(d, 'uploadedBy'),
    originRecordingId: readOptionalString(d, 'originRecordingId'),
    featured: d['featured'] == true,
    publishedAt: readDate(d['publishedAt']),
    createdAt: readDate(d['createdAt']),
    updatedAt: readDate(d['updatedAt']),
  );

  /// Editable metadata fields (no status, ownership or timestamps).
  static Map<String, dynamic> metadataMap(Sermon s) => {
    'title': s.title.trim(),
    'description': s.description.trim(),
    'speakerName': s.speakerName.trim(),
    'scriptureReference': s.scriptureReference.trim(),
    'scriptureQuote': s.scriptureQuote?.trim(),
    'category': s.category,
    'featured': s.featured,
  };
}

/// Storage path conventions (CLAUDE.md §9).
abstract final class SermonPaths {
  static String audio(String sermonId) => 'sermons/published/$sermonId/audio';
  static String cover(String sermonId) => 'sermons/published/$sermonId/cover';
}
