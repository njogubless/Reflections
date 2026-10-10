import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/firestore_utils.dart';
import '../domain/entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watch(String uid, {int limit = 50});
  Stream<int> watchUnreadCount(String uid);
  Future<void> markRead(String uid, String id);
  Future<void> markAllRead(String uid, List<AppNotification> visible);
}

/// Notification records are created server-side (Cloud Functions). Clients
/// may only set `readAt` on their own notifications.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  static AppNotification fromMap(String id, Map<String, dynamic> d) =>
      AppNotification(
        id: id,
        type: NotificationType.fromWire(d['type']),
        title: readString(d, 'title'),
        body: readString(d, 'body'),
        relatedEntityId: readOptionalString(d, 'relatedEntityId'),
        readAt: readDate(d['readAt']),
        createdAt: readDate(d['createdAt']),
      );

  @override
  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) => _col(uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => fromMap(d.id, d.data())).toList());

  @override
  Stream<int> watchUnreadCount(String uid) => _col(
    uid,
  ).where('readAt', isNull: true).limit(100).snapshots().map((s) => s.size);

  @override
  Future<void> markRead(String uid, String id) => guard(
    () => _col(uid).doc(id).update({'readAt': FieldValue.serverTimestamp()}),
  );

  @override
  Future<void> markAllRead(String uid, List<AppNotification> visible) =>
      guard(() async {
        final unread = visible.where((n) => !n.isRead).take(450).toList();
        if (unread.isEmpty) return;
        final batch = _db.batch();
        for (final n in unread) {
          batch.update(_col(uid).doc(n.id), {
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      });
}
