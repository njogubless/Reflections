import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_utils.dart';
import '../../auth/domain/entities/app_user.dart';
import '../domain/entities/activity_entry.dart';

/// Immutable admin audit log (`admin_activity`). Entries are written in the
/// same batch/transaction as the action they describe.
abstract final class ActivityLog {
  static const collection = 'admin_activity';

  static Map<String, dynamic> _entry(
    AppUser admin, {
    required String action,
    required String entityType,
    required String entityId,
    required String summary,
  }) => {
    'actorUid': admin.uid,
    'actorName': admin.displayName,
    'action': action,
    'entityType': entityType,
    'entityId': entityId,
    'summary': summary,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static void addToBatch(
    FirebaseFirestore db,
    WriteBatch batch,
    AppUser admin, {
    required String action,
    required String entityType,
    required String entityId,
    required String summary,
  }) => batch.set(
    db.collection(collection).doc(),
    _entry(
      admin,
      action: action,
      entityType: entityType,
      entityId: entityId,
      summary: summary,
    ),
  );

  static void addToTransaction(
    FirebaseFirestore db,
    Transaction tx,
    AppUser admin, {
    required String action,
    required String entityType,
    required String entityId,
    required String summary,
  }) => tx.set(
    db.collection(collection).doc(),
    _entry(
      admin,
      action: action,
      entityType: entityType,
      entityId: entityId,
      summary: summary,
    ),
  );

  static ActivityEntry fromMap(String id, Map<String, dynamic> d) =>
      ActivityEntry(
        id: id,
        actorUid: readString(d, 'actorUid'),
        actorName: readString(d, 'actorName'),
        action: readString(d, 'action'),
        entityType: readString(d, 'entityType'),
        entityId: readString(d, 'entityId'),
        summary: readString(d, 'summary'),
        createdAt: readDate(d['createdAt']),
      );
}
