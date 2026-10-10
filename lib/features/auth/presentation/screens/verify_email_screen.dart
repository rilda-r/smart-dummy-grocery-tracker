import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/auth_repository.dart';

import '../controllers/auth_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  void _checkVerification() async {
    final controller = ref.read(authControllerProvider.notifier);
    final isVerified = await controller.reloadAndCheckVerification();
    if (!mounted) return;

    if (isVerified) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not verified yet. Please check your inbox and click the link.'),
          backgroundColor: AppColors.rust,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (authState.successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lineGreen),
                      ),
                      child: Text(
                        authState.successMessage!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.forest),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: AppColors.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 64,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Check your email',
                    style: AppTypography.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to:\n${user?.email ?? "your email address"}',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: "I've verified my email",
                    isLoading: authState.isLoading,
                    onPressed: _checkVerification,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: authState.resendCooldown > 0
                        ? 'Resend in ${authState.resendCooldown}s'
                        : 'Resend email',
                    variant: AppButtonVariant.secondary,
                    onPressed: authState.resendCooldown > 0 || authState.isLoading
                        ? null
                        : () => ref.read(authControllerProvider.notifier).resendVerificationEmail(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
