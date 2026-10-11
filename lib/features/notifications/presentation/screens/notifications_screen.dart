import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../domain/models/app_notification.dart';
import '../controllers/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsStreamProvider);
    final controller = ref.read(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Notifications', style: AppTypography.headlineMedium),
        actions: [
          notifsAsync.maybeWhen(
            data: (list) {
              final unreadCount = list.where((n) => !n.isRead).length;
              if (unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => controller.markAllAsRead(),
                icon: const Icon(Icons.done_all, size: 18, color: AppColors.forest),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading notifications: $err',
            style: const TextStyle(color: AppColors.rust),
          ),
        ),
        data: (notifs) {
          if (notifs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              description:
                  'You will see alerts here when items are locked during shopping, groceries expire, or bills are settled.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notif = notifs[index];
              return _NotificationCard(
                notification: notif,
                onTap: () {
                  if (!notif.isRead) {
                    controller.markAsRead(notif.id);
                  }
                },
                onDelete: () => controller.deleteNotification(notif.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.itemLocked:
        return Icons.shopping_basket;
      case NotificationType.itemExpired:
        return Icons.event_busy;
      case NotificationType.expiringSoon:
        return Icons.access_time_filled;
      case NotificationType.lowStock:
        return Icons.inventory_2;
      case NotificationType.billCreated:
        return Icons.receipt_long;
      case NotificationType.paymentSettled:
        return Icons.handshake;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.itemLocked:
        return AppColors.forest;
      case NotificationType.itemExpired:
        return AppColors.rust;
      case NotificationType.expiringSoon:
        return Colors.amber.shade800;
      case NotificationType.lowStock:
        return Colors.orange.shade700;
      case NotificationType.billCreated:
        return AppColors.gold;
      case NotificationType.paymentSettled:
        return AppColors.moss;
      case NotificationType.general:
        return AppColors.forest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _colorForType(notification.type);
    final timeStr = DateFormat('MMM d, h:mm a').format(notification.createdAt);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead ? AppColors.surface : AppColors.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.line
                  : themeColor.withValues(alpha: 0.3),
              width: notification.isRead ? 1 : 1.5,
            ),
            boxShadow: notification.isRead
                ? null
                : [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconForType(notification.type),
                    color: themeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.titleLarge.copyWith(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.rust,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (notification.groupName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.sage.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.groupName!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.forest,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
