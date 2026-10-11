import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../controllers/groups_controller.dart';

/// Reusable AppBar title widget that displays the active room and allows instant switching
class RoomSwitcherAppBarTitle extends ConsumerWidget {
  const RoomSwitcherAppBarTitle({
    super.key,
    this.fallbackTitle,
  });

  final String? fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGroup = ref.watch(activeGroupProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showRoomSwitcherModal(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fallbackTitle != null)
                    Text(
                      fallbackTitle!,
                      style: AppTypography.titleLarge.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 14,
                        color: activeGroup != null
                            ? AppColors.forest
                            : AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          activeGroup?.name ?? 'No room selected',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: activeGroup != null
                                ? AppColors.forest
                                : AppColors.gold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.inkMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showRoomSwitcherModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final activeGroup = ref.watch(activeGroupProvider);
            final userGroupsAsync = ref.watch(userGroupsProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Switch Room', style: AppTypography.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    userGroupsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.forest),
                        ),
                      ),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (groups) {
                        if (groups.isEmpty) {
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.sage,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.home_work_outlined,
                                        size: 40, color: AppColors.forest),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You don\'t belong to any rooms yet!',
                                      style: AppTypography.titleLarge
                                          .copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Create a household room or join with a 6-character code.',
                                      style: AppTypography.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppButton(
                                text: 'Go to Groups to Join or Create',
                                onPressed: () {
                                  Navigator.of(modalCtx).pop();
                                  context.go('/groups');
                                },
                              ),
                            ],
                          );
                        }

                        return Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: groups.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final group = groups[idx];
                              final isSelected = group.id == activeGroup?.id;

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await ref
                                      .read(activeGroupIdProvider.notifier)
                                      .setActiveGroup(group.id);
                                  if (modalCtx.mounted) {
                                    Navigator.of(modalCtx).pop();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.forest
                                          : AppColors.line,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: isSelected
                                            ? AppColors.sage
                                            : AppColors.line.withAlpha(80),
                                        child: Icon(
                                          Icons.group,
                                          color: isSelected
                                              ? AppColors.forest
                                              : AppColors.inkMuted,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.name,
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            Text(
                                              '${group.memberCount} members • Code: ${group.joinCode}',
                                              style: AppTypography.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.forest,
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: AppColors.forest),
                      label: Text(
                        'Manage / Add Groups',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.forest),
                      ),
                      onPressed: () {
                        Navigator.of(modalCtx).pop();
                        context.go('/groups');
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
