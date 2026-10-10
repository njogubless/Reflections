import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/recording_status.dart';
import '../../domain/entities/recording_submission.dart';

abstract final class RecordingModel {
  static const collection = 'recordings';

  static RecordingSubmission fromMap(String id, Map<String, dynamic> d) =>
      RecordingSubmission(
        id: id,
        ownerUid: readString(d, 'ownerUid'),
        ownerName: readString(d, 'ownerName'),
        metadata: SermonMetadata(
          title: readString(d, 'title'),
          description: readString(d, 'description'),
          speakerName: readString(d, 'speakerName'),
          scriptureReference: readString(d, 'scriptureReference'),
        ),
        storagePath: readString(d, 'storagePath'),
        durationSeconds: readInt(d, 'durationSeconds'),
        sizeBytes: readInt(d, 'sizeBytes'),
        status: RecordingStatus.fromWire(d['status']),
        reviewFeedback: readOptionalString(d, 'reviewFeedback'),
        reviewedBy: readOptionalString(d, 'reviewedBy'),
        reviewerName: readOptionalString(d, 'reviewerName'),
        reviewedAt: readDate(d['reviewedAt']),
        submittedAt: readDate(d['submittedAt']),
        publishedSermonId: readOptionalString(d, 'publishedSermonId'),
        revision: readInt(d, 'revision', 1),
        createdAt: readDate(d['createdAt']),
        updatedAt: readDate(d['updatedAt']),
      );

  static Map<String, dynamic> metadataMap(SermonMetadata m) => {
    'title': m.title.trim(),
    'description': m.description.trim(),
    'speakerName': m.speakerName.trim(),
    'scriptureReference': m.scriptureReference.trim(),
  };
}
