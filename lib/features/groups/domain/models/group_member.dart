import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupRole {
  owner,
  member;

  static GroupRole fromString(String? role) {
    if (role == 'owner') return GroupRole.owner;
    return GroupRole.member;
  }

  String get label => this == GroupRole.owner ? 'Owner' : 'Member';
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.email,
    this.role = GroupRole.member,
    required this.joinedAt,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String email;
  final GroupRole role;
  final DateTime joinedAt;
  final String? photoUrl;

  bool get isOwner => role == GroupRole.owner;

  factory GroupMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GroupMember(
      userId: doc.id,
      displayName: data['displayName'] as String? ?? 'Shopper',
      email: data['email'] as String? ?? '',
      role: GroupRole.fromString(data['role'] as String?),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'photoUrl': photoUrl,
    };
  }

  GroupMember copyWith({
    String? userId,
    String? displayName,
    String? email,
    GroupRole? role,
    DateTime? joinedAt,
    String? photoUrl,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
