import 'package:cloud_firestore/cloud_firestore.dart';

enum GroceryStatus { pending, purchased, unavailable }

extension GroceryStatusExt on GroceryStatus {
  String get value {
    switch (this) {
      case GroceryStatus.pending:
        return 'pending';
      case GroceryStatus.purchased:
        return 'purchased';
      case GroceryStatus.unavailable:
        return 'unavailable';
    }
  }

  String get label {
    switch (this) {
      case GroceryStatus.pending:
        return 'Pending';
      case GroceryStatus.purchased:
        return 'Purchased';
      case GroceryStatus.unavailable:
        return 'Unavailable';
    }
  }

  static GroceryStatus fromString(String? s) {
    switch (s) {
      case 'purchased':
        return GroceryStatus.purchased;
      case 'unavailable':
        return GroceryStatus.unavailable;
      default:
        return GroceryStatus.pending;
    }
  }
}

class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.groupId,
    required this.addedBy,
    required this.itemName,
    required this.itemNameLower,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.purchasedQuantity = 0,
    this.lockedBy,
    this.lockedAt,
  });

  final String id;
  final String groupId;
  final String addedBy;
  final String itemName;
  final String itemNameLower; // For case-insensitive duplicate check
  final int quantity;
  final int purchasedQuantity;
  final GroceryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lockedBy; // uid of member who locked this item for purchase
  final DateTime? lockedAt;

  bool get isLocked => lockedBy != null && lockedAt != null;

  /// A lock is stale if older than 10 minutes (prevents phantom locks)
  bool isLockStale(DateTime now) {
    if (lockedAt == null) return false;
    return now.difference(lockedAt!).inMinutes >= 10;
  }

  factory GroceryItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GroceryItem(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      addedBy: data['addedBy'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      itemNameLower: data['itemNameLower'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      purchasedQuantity: (data['purchasedQuantity'] as num?)?.toInt() ?? 0,
      status: GroceryStatusExt.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lockedBy: data['lockedBy'] as String?,
      lockedAt: (data['lockedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'addedBy': addedBy,
      'itemName': itemName,
      'itemNameLower': itemNameLower,
      'quantity': quantity,
      'purchasedQuantity': purchasedQuantity,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lockedBy': lockedBy,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
    };
  }

  GroceryItem copyWith({
    String? id,
    String? groupId,
    String? addedBy,
    String? itemName,
    String? itemNameLower,
    int? quantity,
    int? purchasedQuantity,
    GroceryStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lockedBy,
    DateTime? lockedAt,
    bool clearLock = false,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      addedBy: addedBy ?? this.addedBy,
      itemName: itemName ?? this.itemName,
      itemNameLower: itemNameLower ?? this.itemNameLower,
      quantity: quantity ?? this.quantity,
      purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lockedBy: clearLock ? null : (lockedBy ?? this.lockedBy),
      lockedAt: clearLock ? null : (lockedAt ?? this.lockedAt),
    );
  }
}
