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

enum FreshnessStatus { fresh, soon, expired, none }

extension FreshnessStatusExt on FreshnessStatus {
  String get label {
    switch (this) {
      case FreshnessStatus.fresh:
        return 'Fresh';
      case FreshnessStatus.soon:
        return 'Expiring Soon';
      case FreshnessStatus.expired:
        return 'Expired';
      case FreshnessStatus.none:
        return '';
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
    this.expiryDate,
    this.category,
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
  final DateTime? expiryDate;
  final String? category;

  bool get isLocked => lockedBy != null && lockedAt != null;

  /// A lock is stale if older than 10 minutes (prevents phantom locks)
  bool isLockStale(DateTime now) {
    if (lockedAt == null) return false;
    return now.difference(lockedAt!).inMinutes >= 10;
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return target.difference(today).inDays;
  }

  FreshnessStatus get freshness {
    final days = daysUntilExpiry;
    if (days == null) return FreshnessStatus.none;
    if (days < 0) return FreshnessStatus.expired;
    if (days <= 3) return FreshnessStatus.soon;
    return FreshnessStatus.fresh;
  }

  bool get isLowStock => quantity <= 1;

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
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      category: data['category'] as String?,
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
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'category': category,
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
    DateTime? expiryDate,
    bool clearExpiry = false,
    String? category,
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
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      category: category ?? this.category,
    );
  }
}
