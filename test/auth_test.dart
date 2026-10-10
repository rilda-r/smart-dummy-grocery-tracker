import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocease/core/theme/app_typography.dart';
import 'package:grocease/features/auth/data/auth_repository.dart';
import 'package:grocease/features/auth/domain/app_user.dart';
import 'package:grocease/features/auth/presentation/controllers/auth_controller.dart';
import 'package:grocease/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:grocease/features/auth/presentation/screens/login_screen.dart';
import 'package:grocease/features/auth/presentation/screens/register_screen.dart';
import 'package:grocease/features/auth/presentation/screens/verify_email_screen.dart';

void main() {
  setUpAll(() {
    AppTypography.isTest = true;
  });

  const dummyUser = AppUser(
    uid: 'test_uid_123',
    email: 'test@grocease.com',
    displayName: 'Test User',
    emailVerified: false,
  );

  group('Milestone 2 - Auth Unit & Widget Tests', () {
    test('AuthState initial state has correct defaults', () {
      const state = AuthState();
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.successMessage, isNull);
      expect(state.isLocked, isFalse);
      expect(state.remainingSeconds, 0);
      expect(state.remainingAttempts, 3);
      expect(state.resendCooldown, 0);
    });

    test('AuthState copyWith correctly modifies fields and clears errors', () {
      const state = AuthState(
        isLoading: false,
        errorMessage: 'Initial error',
        isLocked: false,
      );

      final updated = state.copyWith(
        isLoading: true,
        isLocked: true,
        remainingSeconds: 60,
        clearError: true,
      );

      expect(updated.isLoading, isTrue);
      expect(updated.errorMessage, isNull);
      expect(updated.isLocked, isTrue);
      expect(updated.remainingSeconds, 60);
    });

    testWidgets('LoginScreen displays welcome text and input fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _FakeAuthController(const AuthState()),
            ),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('LoginScreen displays lockout banner when state is locked', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _FakeAuthController(
                const AuthState(
                  isLocked: true,
                  remainingSeconds: 45,
                  errorMessage: 'Account is temporarily locked. Try again in 45s.',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Security Lockout Active'), findsOneWidget);
      expect(find.text('Too many failed attempts. Unlock in 45s.'), findsOneWidget);
      expect(find.text('Locked (45s)'), findsOneWidget);
    });

    testWidgets('RegisterScreen renders registration fields and validation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _FakeAuthController(const AuthState()),
            ),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Join GrocEase'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password (min. 8 characters)'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Account'), findsNWidgets(2));
    });

    testWidgets('ForgotPasswordScreen renders instructions and input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) => _FakeAuthController(const AuthState()),
            ),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('VerifyEmailScreen renders verification prompt and cooldown state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(dummyUser),
            authControllerProvider.overrideWith(
              (ref) => _FakeAuthController(
                const AuthState(
                  resendCooldown: 42,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: VerifyEmailScreen(),
          ),
        ),
      );

      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text("I've verified my email"), findsOneWidget);
      expect(find.text('Resend in 42s'), findsOneWidget);
      expect(find.text('We sent a verification link to:\ntest@grocease.com'), findsOneWidget);
    });
  });
}

class _FakeAuthController extends StateNotifier<AuthState> implements AuthController {
  _FakeAuthController(super.initialState);

  @override
  void clearMessages() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
