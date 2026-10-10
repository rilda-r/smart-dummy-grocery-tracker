import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/app_user.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool isLocked;
  final int remainingSeconds;
  final int remainingAttempts;
  final int resendCooldown;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.isLocked = false,
    this.remainingSeconds = 0,
    this.remainingAttempts = 3,
    this.resendCooldown = 0,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool? isLocked,
    int? remainingSeconds,
    int? remainingAttempts,
    int? resendCooldown,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      isLocked: isLocked ?? this.isLocked,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      remainingAttempts: remainingAttempts ?? this.remainingAttempts,
      resendCooldown: resendCooldown ?? this.resendCooldown,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final AuthRepository _repository;
  Timer? _lockoutTimer;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    state = state.copyWith(
      isLocked: true,
      remainingSeconds: seconds,
      errorMessage: 'Account is temporarily locked. Try again in ${seconds}s.',
    );

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(
          isLocked: false,
          remainingSeconds: 0,
          remainingAttempts: 3,
          clearError: true,
        );
      } else {
        final nextSeconds = state.remainingSeconds - 1;
        state = state.copyWith(
          remainingSeconds: nextSeconds,
          errorMessage: 'Account is temporarily locked. Try again in ${nextSeconds}s.',
        );
      }
    });
  }

  void _startCooldownCountdown(int seconds) {
    _cooldownTimer?.cancel();
    state = state.copyWith(resendCooldown: seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCooldown <= 1) {
        timer.cancel();
        state = state.copyWith(resendCooldown: 0);
      } else {
        state = state.copyWith(resendCooldown: state.resendCooldown - 1);
      }
    });
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter both email and password.');
      return false;
    }

    if (state.isLocked) {
      state = state.copyWith(
        errorMessage: 'Account is locked. Please wait ${state.remainingSeconds}s.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // 1. Check server-side lockout status via Cloud Function
      final lockStatus = await _repository.checkLockStatus(cleanEmail);
      if (lockStatus['isLocked'] == true) {
        final remainingSec = (lockStatus['remainingSeconds'] as num?)?.toInt() ?? 900;
        state = state.copyWith(isLoading: false);
        _startLockoutCountdown(remainingSec);
        return false;
      }

      // 2. Perform Firebase Auth sign-in
      await _repository.signIn(email: cleanEmail, password: password);
      state = state.copyWith(isLoading: false, remainingAttempts: 3);
      return true;
    } on FirebaseAuthException catch (e) {
      // 3. Handle credential failure with server lockout tracking
      final isCredentialFailure = e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-credential';

      if (isCredentialFailure) {
        final lockResult = await _repository.recordFailedLogin(cleanEmail);
        final isLocked = lockResult['isLocked'] == true;
        final remainingSec = (lockResult['remainingSeconds'] as num?)?.toInt() ?? 900;
        final remainingAttempts = (lockResult['remainingAttempts'] as num?)?.toInt() ?? 0;

        if (isLocked) {
          state = state.copyWith(isLoading: false);
          _startLockoutCountdown(remainingSec);
          return false;
        } else {
          state = state.copyWith(
            isLoading: false,
            remainingAttempts: remainingAttempts,
            errorMessage: 'Invalid email or password. $remainingAttempts attempt(s) remaining before a 15-minute lockout.',
          );
          return false;
        }
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Sign-in failed. Please try again.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = fullName.trim();

    if (cleanName.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your name.');
      return null;
    }
    if (cleanEmail.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter an email address.');
      return null;
    }
    if (password.length < 8) {
      state = state.copyWith(errorMessage: 'Password must be at least 8 characters long.');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final user = await _repository.signUp(
        email: cleanEmail,
        password: password,
        fullName: cleanName,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Account created! Please check your email to verify.',
      );
      _startCooldownCountdown(60);
      return user;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Registration failed. Please try again.',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your email address.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _repository.sendPasswordResetEmail(cleanEmail);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'If an account exists for this email, password reset instructions have been sent.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        successMessage: 'If an account exists for this email, password reset instructions have been sent.',
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    if (state.resendCooldown > 0) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendEmailVerification();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Verification email resent!',
      );
      _startCooldownCountdown(60);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to send verification email. Please try again later.',
      );
    }
  }

  Future<bool> reloadAndCheckVerification() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final verified = await _repository.reloadAndCheckVerification();
      state = state.copyWith(isLoading: false);
      return verified;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Verification check failed.');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteUserData();
      await _repository.signOut();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete account. Please re-authenticate and try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }
}
