import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _submitted = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _submitted
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 64, color: AppColors.forest),
                        const SizedBox(height: 16),
                        Text('Check your inbox', style: AppTypography.displayMedium),
                        const SizedBox(height: 12),
                        Text(
                          'If an account exists for ${_emailController.text.trim()}, instructions have been sent to reset your password.',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        AppButton(
                          text: 'Back to Sign In',
                          onPressed: () => context.go('/login'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Forgot password?', style: AppTypography.displayLarge),
                        const SizedBox(height: 6),
                        Text(
                          "Enter your email and we'll send a password recovery link.",
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 32),
                        AppTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hintText: 'alex@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          text: 'Send Reset Link',
                          isLoading: _isLoading,
                          onPressed: _submit,
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
