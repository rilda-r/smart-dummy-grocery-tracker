import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Avatar & Name Card
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.forest,
                      child: Text(
                        (user?.displayName.isNotEmpty == true
                                ? user!.displayName[0]
                                : 'U')
                            .toUpperCase(),
                        style: AppTypography.headlineMedium.copyWith(color: AppColors.paper),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Shopper',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Danger Zone
              Text(
                'Danger Zone',
                style: AppTypography.titleLarge.copyWith(color: AppColors.rust),
              ),
              const SizedBox(height: 8),
              AppCard(
                borderColor: AppColors.rust,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Account',
                      style: AppTypography.titleLarge.copyWith(color: AppColors.rust),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Permanently remove your account, memberships, and receipts. If you are the sole group owner, owned groups will be deleted.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Delete My Account',
                      variant: AppButtonVariant.danger,
                      onPressed: () => _confirmDeleteAccount(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Sign Out Button
              AppButton(
                text: 'Sign Out',
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/login?reason=${Uri.encodeComponent('You have been signed out.')}');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text(
            'Delete Account?',
            style: AppTypography.titleLarge.copyWith(color: AppColors.rust),
          ),
          content: Text(
            'This action is irreversible. All your personal data, group memberships, and uploaded receipts will be deleted.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.inkMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rust),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final scaffold = ScaffoldMessenger.of(context);
                final success = await ref.read(authControllerProvider.notifier).deleteAccount();
                if (success && context.mounted) {
                  context.go('/login?reason=${Uri.encodeComponent('Account and associated data deleted.')}');
                } else if (!success && context.mounted) {
                  scaffold.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete account. Please re-authenticate and retry.'),
                      backgroundColor: AppColors.rust,
                    ),
                  );
                }
              },
              child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
