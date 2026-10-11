import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_notification.dart';
import '../../../lists/domain/models/grocery_item.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(FirebaseFirestore.instance);
});

class NotificationsRepository {
  NotificationsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userNotifsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  /// Watch real-time notifications for a user, sorted newest first
  Stream<List<AppNotification>> watchNotifications(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _userNotifsCol(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AppNotification.fromFirestore).toList());
  }

  /// Mark single notification as read
  Future<void> markAsRead(String userId, String notifId) async {
    await _userNotifsCol(userId).doc(notifId).update({'isRead': true});
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    final snap = await _userNotifsCol(userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete notification
  Future<void> deleteNotification(String userId, String notifId) async {
    await _userNotifsCol(userId).doc(notifId).delete();
  }

  /// Send notification to a specific user
  Future<AppNotification> sendNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    String? groupId,
    String? groupName,
    Map<String, dynamic>? data,
  }) async {
    final docRef = _userNotifsCol(userId).doc();
    final notif = AppNotification(
      id: docRef.id,
      userId: userId,
      groupId: groupId,
      groupName: groupName,
      title: title,
      body: body,
      type: type,
      data: data,
      isRead: false,
      createdAt: DateTime.now(),
    );
    await docRef.set(notif.toFirestore());
    return notif;
  }

  /// Broadcast notification to all members of a group
  Future<void> broadcastToGroup({
    required List<String> memberIds,
    required String title,
    required String body,
    required NotificationType type,
    required String groupId,
    String? groupName,
    String? excludeUserId,
    Map<String, dynamic>? data,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (final uid in memberIds) {
      if (excludeUserId != null && uid == excludeUserId) continue;
      final docRef = _userNotifsCol(uid).doc();
      final notif = AppNotification(
        id: docRef.id,
        userId: uid,
        groupId: groupId,
        groupName: groupName,
        title: title,
        body: body,
        type: type,
        data: data,
        isRead: false,
        createdAt: now,
      );
      batch.set(docRef, notif.toFirestore());
    }

    await batch.commit();
  }

  /// Check grocery items for expiration and low stock alerts
  Future<void> checkAndAlertGroceryStatus({
    required String groupId,
    required String groupName,
    required List<String> memberUserIds,
    required List<GroceryItem> items,
  }) async {
    for (final item in items) {
      if (item.status != GroceryStatus.pending) continue;

      if (item.freshness == FreshnessStatus.expired) {
        await broadcastToGroup(
          memberIds: memberUserIds,
          title: '🚨 Item Expired: ${item.itemName}',
          body: '${item.itemName} in $groupName has passed its expiration date.',
          type: NotificationType.itemExpired,
          groupId: groupId,
          groupName: groupName,
          data: {'itemId': item.id, 'itemName': item.itemName},
        );
      } else if (item.freshness == FreshnessStatus.soon) {
        final days = item.daysUntilExpiry ?? 0;
        await broadcastToGroup(
          memberIds: memberUserIds,
          title: '⚠️ Expiring Soon: ${item.itemName}',
          body: '${item.itemName} expires in $days ${days == 1 ? "day" : "days"}!',
          type: NotificationType.expiringSoon,
          groupId: groupId,
          groupName: groupName,
          data: {'itemId': item.id, 'itemName': item.itemName},
        );
      }
    }
  }
}
