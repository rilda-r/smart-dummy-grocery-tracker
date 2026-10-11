import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocease/core/theme/app_typography.dart';
import 'package:grocease/features/groups/domain/models/group.dart';
import 'package:grocease/features/groups/presentation/controllers/groups_controller.dart';
import 'package:grocease/features/groups/presentation/widgets/room_switcher_title.dart';
import 'package:grocease/features/notifications/domain/models/app_notification.dart';
import 'package:grocease/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:grocease/features/notifications/presentation/widgets/notification_bell_icon.dart';

void main() {
  setUpAll(() {
    AppTypography.isTest = true;
  });

  group('AppNotification Model Tests', () {
    test('creates and converts to/from Map correctly', () {
      final now = DateTime.now();
      final notif = AppNotification(
        id: 'notif_1',
        userId: 'user_1',
        title: 'Item Locked',
        body: 'Alice locked Milk for shopping',
        type: NotificationType.itemLocked,
        isRead: false,
        createdAt: now,
        groupId: 'grp_1',
        groupName: 'Apartment 4B',
      );

      final map = notif.toMap();
      expect(map['userId'], 'user_1');
      expect(map['title'], 'Item Locked');
      expect(map['type'], 'item_locked');
      expect(map['isRead'], false);
      expect(map['groupId'], 'grp_1');
      expect(map['groupName'], 'Apartment 4B');

      final fromMap = AppNotification.fromMap('notif_1', map);
      expect(fromMap.id, 'notif_1');
      expect(fromMap.userId, 'user_1');
      expect(fromMap.type, NotificationType.itemLocked);
      expect(fromMap.isRead, false);
      expect(fromMap.groupName, 'Apartment 4B');
    });

    test('notification copyWith updates isRead flag', () {
      final notif = AppNotification(
        id: 'notif_2',
        userId: 'user_1',
        title: 'Bill Settled',
        body: 'Dave paid your share',
        type: NotificationType.paymentSettled,
        isRead: false,
        createdAt: DateTime.now(),
      );

      final updated = notif.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.title, 'Bill Settled');
    });
  });

  group('NotificationBellIcon Widget Tests', () {
    testWidgets('shows badge with unread count when greater than 0',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWithValue(3),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: Row(
                  children: [
                    NotificationBellIcon(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides badge when unread count is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWithValue(0),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: Row(
                  children: [
                    NotificationBellIcon(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('RoomSwitcherAppBarTitle Widget Tests', () {
    final testGroup = Group(
      id: 'grp_123',
      name: 'Baker Street Flat',
      joinCode: 'BK1234',
      ownerId: 'owner_1',
      memberIds: const ['owner_1'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('displays active group name and down arrow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeGroupProvider.overrideWithValue(testGroup),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: RoomSwitcherAppBarTitle(fallbackTitle: 'GrocEase'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Baker Street Flat'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('displays fallbackTitle when activeGroup is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeGroupProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: RoomSwitcherAppBarTitle(fallbackTitle: 'Shared Lists'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Shared Lists'), findsOneWidget);
    });
  });
}
