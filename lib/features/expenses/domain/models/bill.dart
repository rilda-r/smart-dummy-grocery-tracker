import 'package:cloud_firestore/cloud_firestore.dart';

enum OcrStatus { pending, processing, completed, failed }

extension OcrStatusExt on OcrStatus {
  String get value {
    switch (this) {
      case OcrStatus.pending:
        return 'pending';
      case OcrStatus.processing:
        return 'processing';
      case OcrStatus.completed:
        return 'completed';
      case OcrStatus.failed:
        return 'failed';
    }
  }

  static OcrStatus fromString(String? s) {
    switch (s) {
      case 'processing':
        return OcrStatus.processing;
      case 'completed':
        return OcrStatus.completed;
      case 'failed':
        return OcrStatus.failed;
      default:
        return OcrStatus.pending;
    }
  }
}

class Bill {
  const Bill({
    required this.id,
    required this.groupId,
    required this.uploadedBy,
    required this.fileName,
    required this.ocrStatus,
    required this.totalAmount,
    required this.createdAt,
    this.splitType,
    this.splitConfirmed = false,
  });

  final String id;
  final String groupId;
  final String uploadedBy;
  final String fileName;
  final OcrStatus ocrStatus;
  final double totalAmount;
  final DateTime createdAt;
  final String? splitType; // 'equal' | 'member_wise'
  final bool splitConfirmed;

  factory Bill.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Bill(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      uploadedBy: data['uploadedBy'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      ocrStatus: OcrStatusExt.fromString(data['ocrStatus'] as String?),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      splitType: data['splitType'] as String?,
      splitConfirmed: data['splitConfirmed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'uploadedBy': uploadedBy,
        'fileName': fileName,
        'ocrStatus': ocrStatus.value,
        'totalAmount': totalAmount,
        'createdAt': Timestamp.fromDate(createdAt),
        'splitType': splitType,
        'splitConfirmed': splitConfirmed,
      };

  Bill copyWith({
    String? id,
    String? groupId,
    String? uploadedBy,
    String? fileName,
    OcrStatus? ocrStatus,
    double? totalAmount,
    DateTime? createdAt,
    String? splitType,
    bool? splitConfirmed,
  }) =>
      Bill(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        uploadedBy: uploadedBy ?? this.uploadedBy,
        fileName: fileName ?? this.fileName,
        ocrStatus: ocrStatus ?? this.ocrStatus,
        totalAmount: totalAmount ?? this.totalAmount,
        createdAt: createdAt ?? this.createdAt,
        splitType: splitType ?? this.splitType,
        splitConfirmed: splitConfirmed ?? this.splitConfirmed,
      );
}

class BillItem {
  const BillItem({
    required this.id,
    required this.billId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.matchedGroceryItemId,
    this.assignedUserId,
  });

  final String id;
  final String billId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? matchedGroceryItemId;
  final String? assignedUserId;

  factory BillItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BillItem(
      id: doc.id,
      billId: data['billId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      matchedGroceryItemId: data['matchedGroceryItemId'] as String?,
      assignedUserId: data['assignedUserId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'billId': billId,
        'itemName': itemName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'matchedGroceryItemId': matchedGroceryItemId,
        'assignedUserId': assignedUserId,
      };

  BillItem copyWith({
    String? id,
    String? billId,
    String? itemName,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? matchedGroceryItemId,
    String? assignedUserId,
    bool clearAssignment = false,
    bool clearGroceryMatch = false,
  }) =>
      BillItem(
        id: id ?? this.id,
        billId: billId ?? this.billId,
        itemName: itemName ?? this.itemName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        matchedGroceryItemId:
            clearGroceryMatch ? null : (matchedGroceryItemId ?? this.matchedGroceryItemId),
        assignedUserId:
            clearAssignment ? null : (assignedUserId ?? this.assignedUserId),
      );
}
