import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  itemLocked,
  itemExpired,
  expiringSoon,
  lowStock,
  billCreated,
  paymentSettled,
  general,
}

extension NotificationTypeExt on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.itemLocked:
        return 'item_locked';
      case NotificationType.itemExpired:
        return 'item_expired';
      case NotificationType.expiringSoon:
        return 'expiring_soon';
      case NotificationType.lowStock:
        return 'low_stock';
      case NotificationType.billCreated:
        return 'bill_created';
      case NotificationType.paymentSettled:
        return 'payment_settled';
      case NotificationType.general:
        return 'general';
    }
  }

  static NotificationType fromString(String? val) {
    switch (val) {
      case 'item_locked':
        return NotificationType.itemLocked;
      case 'item_expired':
        return NotificationType.itemExpired;
      case 'expiring_soon':
        return NotificationType.expiringSoon;
      case 'low_stock':
        return NotificationType.lowStock;
      case 'bill_created':
        return NotificationType.billCreated;
      case 'payment_settled':
        return NotificationType.paymentSettled;
      default:
        return NotificationType.general;
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    this.groupId,
    this.groupName,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? groupId;
  final String? groupName;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      groupId: d['groupId'] as String?,
      groupName: d['groupName'] as String?,
      title: d['title'] as String? ?? 'Notification',
      body: d['body'] as String? ?? '',
      type: NotificationTypeExt.fromString(d['type'] as String?),
      data: d['data'] as Map<String, dynamic>?,
      isRead: d['isRead'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> d) {
    DateTime parsedDate;
    final createdVal = d['createdAt'];
    if (createdVal is Timestamp) {
      parsedDate = createdVal.toDate();
    } else if (createdVal is DateTime) {
      parsedDate = createdVal;
    } else if (createdVal is String) {
      parsedDate = DateTime.tryParse(createdVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return AppNotification(
      id: id,
      userId: d['userId'] as String? ?? '',
      groupId: d['groupId'] as String?,
      groupName: d['groupName'] as String?,
      title: d['title'] as String? ?? 'Notification',
      body: d['body'] as String? ?? '',
      type: NotificationTypeExt.fromString(d['type'] as String?),
      data: d['data'] as Map<String, dynamic>?,
      isRead: d['isRead'] as bool? ?? false,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'groupName': groupName,
      'title': title,
      'body': body,
      'type': type.value,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'groupId': groupId,
      'groupName': groupName,
      'title': title,
      'body': body,
      'type': type.value,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? groupId,
    String? groupName,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
