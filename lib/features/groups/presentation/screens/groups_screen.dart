import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/models/group.dart';
import '../controllers/groups_controller.dart';
import '../../../notifications/presentation/widgets/notification_bell_icon.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final activeGroup = ref.watch(activeGroupProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            icon: const Icon(Icons.key_outlined),
            onPressed: () => _showJoinGroupSheet(context),
          ),
          IconButton(
            tooltip: 'Create new group',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showCreateGroupSheet(context),
          ),
          const NotificationBellIcon(),
        ],
      ),
      body: SafeArea(
        child: groupsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.forest),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error loading groups: $err',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.rust),
            ),
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppEmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No groups joined yet',
                        description:
                            'Collaborate on grocery runs by creating a shared household or joining one with a 6-character code.',
                      ),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          children: [
                            AppButton(
                              text: 'Create New Group',
                              icon: const Icon(Icons.add, color: Colors.white, size: 20),
                              onPressed: () => _showCreateGroupSheet(context),
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              text: 'Join with 6-Char Code',
                              variant: AppButtonVariant.secondary,
                              icon: const Icon(Icons.key_outlined, size: 18),
                              onPressed: () => _showJoinGroupSheet(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final currentGroup = activeGroup ?? groups.first;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Group Header Banner
                    _buildActiveGroupCard(context, currentGroup),
                    const SizedBox(height: 24),

                    // Members of Active Group
                    Text(
                      'Group Members (${currentGroup.memberCount})',
                      style: AppTypography.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildMembersList(context, currentGroup.id),
                    const SizedBox(height: 28),

                    // Switch Group Section
                    if (groups.length > 1) ...[
                      Text('All Groups (${groups.length})', style: AppTypography.headlineMedium),
                      const SizedBox(height: 12),
                      ...groups.map(
                        (g) => _buildGroupTile(context, g, isSelected: g.id == currentGroup.id),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveGroupCard(BuildContext context, Group group) {
    return AppCard(
      borderColor: AppColors.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_outlined, color: AppColors.forest, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: AppTypography.displayMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sage,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.lineGreen),
                          ),
                          child: Text(
                            group.currency,
                            style: AppTypography.labelMedium.copyWith(color: AppColors.forest),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active Workspace',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.moss),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _copyCodeToClipboard(context, group.joinCode),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key, size: 16, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text(
                          group.joinCode,
                          style: AppTypography.labelLarge.copyWith(
                            letterSpacing: 2.0,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.copy, size: 14, color: AppColors.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                text: 'Invite',
                isFullWidth: false,
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
                onPressed: () => _showInviteDialog(context, group),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(BuildContext context, String groupId) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return membersAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.forest, strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text('Error loading members: $e', style: AppTypography.bodySmall),
      data: (members) {
        if (members.isEmpty) {
          return const Text('No members listed yet.', style: TextStyle(color: AppColors.inkMuted));
        }

        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: member.isOwner ? AppColors.forest : AppColors.sage,
                  foregroundColor: member.isOwner ? Colors.white : AppColors.forest,
                  child: Text(
                    member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(member.displayName, style: AppTypography.bodyMedium),
                subtitle: Text(member.email, style: AppTypography.bodySmall),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: member.isOwner ? AppColors.forest : AppColors.sage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    member.role.label,
                    style: AppTypography.labelMedium.copyWith(
                      color: member.isOwner ? Colors.white : AppColors.forest,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGroupTile(BuildContext context, Group group, {required bool isSelected}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        borderColor: isSelected ? AppColors.forest : AppColors.line,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(group.name, style: AppTypography.titleLarge),
          subtitle: Text('${group.memberCount} members • Code: ${group.joinCode}'),
          trailing: isSelected
              ? const Chip(
                  label: Text('Active'),
                  backgroundColor: AppColors.sage,
                  labelStyle: TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
                )
              : OutlinedButton(
                  onPressed: () {
                    ref.read(activeGroupIdProvider.notifier).setActiveGroup(group.id);
                  },
                  child: const Text('Switch'),
                ),
        ),
      ),
    );
  }

  void _copyCodeToClipboard(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Join code "$code" copied to clipboard!'),
        backgroundColor: AppColors.forest,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text('Invite to ${group.name}', style: AppTypography.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this 6-character code with your roommates or household members:',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.forest, width: 2),
                ),
                child: Text(
                  group.joinCode,
                  style: AppTypography.displayLarge.copyWith(
                    letterSpacing: 6,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Anyone with this code can join and view shared lists & expenses.',
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
              icon: const Icon(Icons.copy, size: 16, color: Colors.white),
              label: const Text('Copy Code', style: TextStyle(color: Colors.white)),
              onPressed: () {
                _copyCodeToClipboard(context, group.joinCode);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    final nameController = TextEditingController();
    String selectedCurrency = 'USD';
    final currencies = ['USD', 'EUR', 'GBP', 'INR', 'CAD', 'AUD'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final groupsState = ref.watch(groupsControllerProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create New Group', style: AppTypography.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Setup a shared workspace for your house or grocery run.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: nameController,
                    label: 'Group Name',
                    hintText: 'e.g. Maple Street House, Room 402',
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                  const SizedBox(height: 16),
                  Text('Default Currency', style: AppTypography.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: currencies.map((curr) {
                      final isSelected = curr == selectedCurrency;
                      return ChoiceChip(
                        label: Text(curr),
                        selected: isSelected,
                        selectedColor: AppColors.sage,
                        onSelected: (_) {
                          setModalState(() => selectedCurrency = curr);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Create Group',
                    isLoading: groupsState.isLoading,
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.length < 2) return;

                      final group = await ref.read(groupsControllerProvider.notifier).createGroup(
                            name: name,
                            currency: selectedCurrency,
                          );
                      if (group != null && ctx.mounted) {
                        Navigator.of(bottomCtx).pop();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showJoinGroupSheet(BuildContext context) {
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final groupsState = ref.watch(groupsControllerProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Join a Group', style: AppTypography.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the 6-character code provided by your group owner.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: codeController,
                    label: 'Invite Code',
                    hintText: 'e.g. 7X8K2M',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Join Group',
                    isLoading: groupsState.isLoading,
                    onPressed: () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) return;

                      final group = await ref
                          .read(groupsControllerProvider.notifier)
                          .joinGroupWithCode(code);
                      if (group != null && ctx.mounted) {
                        Navigator.of(bottomCtx).pop();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
