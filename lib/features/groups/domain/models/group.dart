import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    this.currency = 'USD',
    required this.ownerId,
    required this.memberIds,
    required this.joinCode,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String currency;
  final String ownerId;
  final List<String> memberIds;
  final String joinCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoUrl;

  int get memberCount => memberIds.length;

  factory Group.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Group(
      id: doc.id,
      name: data['name'] as String? ?? 'Shared Group',
      currency: data['currency'] as String? ?? 'USD',
      ownerId: data['ownerId'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
      joinCode: (data['joinCode'] as String? ?? '').toUpperCase(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'currency': currency,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'joinCode': joinCode.toUpperCase(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'photoUrl': photoUrl,
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? currency,
    String? ownerId,
    List<String>? memberIds,
    String? joinCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? photoUrl,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      joinCode: joinCode ?? this.joinCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
