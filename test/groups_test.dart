import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocease/core/theme/app_typography.dart';
import 'package:grocease/features/groups/data/repositories/groups_repository.dart';
import 'package:grocease/features/groups/domain/models/group.dart';
import 'package:grocease/features/groups/domain/models/group_member.dart';
import 'package:grocease/features/groups/domain/models/invite_code.dart';
import 'package:grocease/features/groups/presentation/controllers/groups_controller.dart';
import 'package:grocease/features/groups/presentation/screens/groups_screen.dart';

void main() {
  setUpAll(() {
    AppTypography.isTest = true;
  });

  final testGroup = Group(
    id: 'grp_123',
    name: 'Maple Street House',
    currency: 'USD',
    ownerId: 'usr_owner_1',
    memberIds: ['usr_owner_1', 'usr_member_2'],
    joinCode: 'MAPLE8',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
  );

  final testMember = GroupMember(
    userId: 'usr_owner_1',
    displayName: 'Alex Owner',
    email: 'alex@example.com',
    role: GroupRole.owner,
    joinedAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  group('Milestone 3 - Groups & Invites Unit Tests', () {
    test('Group model attributes and copyWith match specification', () {
      expect(testGroup.id, 'grp_123');
      expect(testGroup.name, 'Maple Street House');
      expect(testGroup.currency, 'USD');
      expect(testGroup.memberCount, 2);
      expect(testGroup.joinCode, 'MAPLE8');

      final updated = testGroup.copyWith(name: 'Pine Street House');
      expect(updated.name, 'Pine Street House');
      expect(updated.id, 'grp_123');
    });

    test('GroupMember correctly identifies owner and roles', () {
      expect(testMember.isOwner, isTrue);
      expect(testMember.role.label, 'Owner');

      final regularMember = testMember.copyWith(role: GroupRole.member);
      expect(regularMember.isOwner, isFalse);
      expect(regularMember.role.label, 'Member');
    });

    test('InviteCode validation checks expiry and usage', () {
      final validInvite = InviteCode(
        code: 'MAPLE8',
        groupId: 'grp_123',
        groupName: 'Maple Street',
        createdBy: 'usr_owner_1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
        usedCount: 3,
        maxUses: 10,
      );
      expect(validInvite.isValid, isTrue);
      expect(validInvite.isExpired, isFalse);

      final expiredInvite = InviteCode(
        code: 'EXPR01',
        groupId: 'grp_123',
        groupName: 'Maple Street',
        createdBy: 'usr_owner_1',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(expiredInvite.isExpired, isTrue);
      expect(expiredInvite.isValid, isFalse);
    });

    test('GroupsRepository.generateJoinCode produces a 6-character uppercase code', () {
      final code1 = GroupsRepository.generateJoinCode();
      final code2 = GroupsRepository.generateJoinCode();

      expect(code1.length, 6);
      expect(code2.length, 6);
      expect(code1, code1.toUpperCase());
      expect(code2, code2.toUpperCase());
      expect(code1 != code2, isTrue);
    });
  });

  group('Milestone 3 - GroupsScreen Widget Tests', () {
    testWidgets('GroupsScreen renders empty state when user has no groups', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userGroupsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: GroupsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Groups'), findsOneWidget);
      expect(find.text('No groups joined yet'), findsOneWidget);
      expect(find.text('Create New Group'), findsOneWidget);
      expect(find.text('Join with 6-Char Code'), findsOneWidget);
    });

    testWidgets('GroupsScreen renders active group card, name, and join code', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userGroupsProvider.overrideWith((ref) => Stream.value([testGroup])),
            activeGroupIdProvider.overrideWith((ref) => testGroup.id),
            groupMembersProvider(testGroup.id).overrideWith((ref) => Stream.value([testMember])),
          ],
          child: const MaterialApp(
            home: GroupsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Maple Street House'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('Active Workspace'), findsOneWidget);
      expect(find.text('MAPLE8'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
      expect(find.text('Group Members (2)'), findsOneWidget);
      expect(find.text('Alex Owner'), findsOneWidget);
    });
  });
}
