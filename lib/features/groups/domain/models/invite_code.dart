import 'package:cloud_firestore/cloud_firestore.dart';

class InviteCode {
  const InviteCode({
    required this.code,
    required this.groupId,
    required this.groupName,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.usedCount = 0,
    this.maxUses = 20,
  });

  final String code;
  final String groupId;
  final String groupName;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int usedCount;
  final int maxUses;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isExhausted => usedCount >= maxUses;
  bool get isValid => !isExpired && !isExhausted;

  factory InviteCode.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return InviteCode(
      code: doc.id,
      groupId: data['groupId'] as String? ?? '',
      groupName: data['groupName'] as String? ?? 'Shared Group',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 48)),
      usedCount: (data['usedCount'] as num?)?.toInt() ?? 0,
      maxUses: (data['maxUses'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code.toUpperCase(),
      'groupId': groupId,
      'groupName': groupName,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'usedCount': usedCount,
      'maxUses': maxUses,
    };
  }
}
