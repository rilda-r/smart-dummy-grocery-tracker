import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/app_user.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(firestore: FirebaseFirestore.instance);
});

class GroupsRepository {
  GroupsRepository({required this.firestore});

  final FirebaseFirestore firestore;

  /// Generate unambiguous 6-character uppercase alphanumeric code
  static String generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new shared group with creator as owner
  Future<Group> createGroup({
    required String name,
    required String currency,
    required AppUser user,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw Exception('Group name must be at least 2 characters long.');
    }

    final groupRef = firestore.collection('groups').doc();
    final joinCode = generateJoinCode();
    final now = DateTime.now();

    final group = Group(
      id: groupRef.id,
      name: cleanName,
      currency: currency.toUpperCase(),
      ownerId: user.uid,
      memberIds: [user.uid],
      joinCode: joinCode,
      createdAt: now,
      updatedAt: now,
    );

    final member = GroupMember(
      userId: user.uid,
      displayName: user.displayName.isNotEmpty ? user.displayName : 'Group Owner',
      email: user.email,
      role: GroupRole.owner,
      joinedAt: now,
    );

    final batch = firestore.batch();
    batch.set(groupRef, group.toFirestore());
    batch.set(groupRef.collection('members').doc(user.uid), member.toFirestore());
    await batch.commit();

    return group;
  }

  /// Real-time stream of all groups where the user is a member
  Stream<List<Group>> watchUserGroups(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final groups = snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
      groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return groups;
    });
  }

  /// Real-time stream of members within a group
  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    if (groupId.isEmpty) return Stream.value([]);
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      final members = snapshot.docs.map((doc) => GroupMember.fromFirestore(doc)).toList();
      // Put owners first, then alphabetical
      members.sort((a, b) {
        if (a.isOwner && !b.isOwner) return -1;
        if (!a.isOwner && b.isOwner) return 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
      return members;
    });
  }

  /// Join an existing group using its 6-character code
  Future<Group> joinGroupWithCode({
    required String code,
    required AppUser user,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) {
      throw Exception('Join code must be exactly 6 characters.');
    }

    final querySnapshot = await firestore
        .collection('groups')
        .where('joinCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('No group found with code "$cleanCode". Please verify with your group owner.');
    }

    final groupDoc = querySnapshot.docs.first;
    final group = Group.fromFirestore(groupDoc);

    // If user already in group, return it
    if (group.memberIds.contains(user.uid)) {
      return group;
    }

    final now = DateTime.now();
    final newMember = GroupMember(
      userId: user.uid,
      displayName: user.displayName.isNotEmpty ? user.displayName : 'New Member',
      email: user.email,
      role: GroupRole.member,
      joinedAt: now,
    );

    final batch = firestore.batch();
    batch.update(groupDoc.reference, {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(groupDoc.reference.collection('members').doc(user.uid), newMember.toFirestore());
    await batch.commit();

    return group.copyWith(
      memberIds: [...group.memberIds, user.uid],
      updatedAt: now,
    );
  }

  /// Regenerate a fresh 6-character code (owner only)
  Future<String> regenerateJoinCode({
    required String groupId,
    required String requesterId,
  }) async {
    final newCode = generateJoinCode();
    await firestore.collection('groups').doc(groupId).update({
      'joinCode': newCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return newCode;
  }

  /// Leave group
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final groupDoc = await firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final group = Group.fromFirestore(groupDoc);
    final batch = firestore.batch();

    if (group.memberIds.length <= 1) {
      // Sole member leaving -> delete group
      batch.delete(groupDoc.reference);
      batch.delete(groupDoc.reference.collection('members').doc(userId));
    } else {
      batch.update(groupDoc.reference, {
        'memberIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.delete(groupDoc.reference.collection('members').doc(userId));
    }

    await batch.commit();
  }
}
