import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.userChanges().map((user) => user == null ? null : AppUser.fromFirebase(user));
});

final currentUserProvider = Provider<AppUser?>((ref) {
  final streamedUser = ref.watch(authStateChangesProvider).value;
  if (streamedUser != null) return streamedUser;
  final current = ref.watch(firebaseAuthProvider).currentUser;
  return current == null ? null : AppUser.fromFirebase(current);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instance,
  );
});

class AuthRepository {
  AuthRepository({
    required this.auth,
    required this.firestore,
    required this.functions,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  Stream<AppUser?> get userChanges =>
      auth.userChanges().map((u) => u == null ? null : AppUser.fromFirebase(u));

  AppUser? get currentUser =>
      auth.currentUser == null ? null : AppUser.fromFirebase(auth.currentUser!);

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(fullName.trim());

    // Create user document in users/{uid}
    await firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': fullName.trim(),
      'email': user.email ?? email.trim(),
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'fcmTokens': <String>[],
    });

    // Send email verification
    await user.sendEmailVerification();

    return AppUser.fromFirebase(user);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AppUser.fromFirebase(credential.user!);
  }

  Future<void> sendEmailVerification() async {
    final user = auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> reloadAndCheckVerification() async {
    final user = auth.currentUser;
    if (user != null) {
      await user.reload();
      return auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } catch (_) {
      // Intentionally suppress errors to not disclose account existence
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<Map<String, dynamic>> checkLockStatus(String email) async {
    try {
      final callable = functions.httpsCallable('checkLockStatus');
      final result = await callable.call<Map<String, dynamic>>({'email': email});
      return Map<String, dynamic>.from(result.data);
    } catch (_) {
      return {'isLocked': false, 'remainingSeconds': 0, 'remainingAttempts': 3};
    }
  }

  Future<Map<String, dynamic>> recordFailedLogin(String email) async {
    try {
      final callable = functions.httpsCallable('recordFailedLogin');
      final result = await callable.call<Map<String, dynamic>>({'email': email});
      return Map<String, dynamic>.from(result.data);
    } catch (_) {
      return {'isLocked': false, 'remainingSeconds': 0, 'remainingAttempts': 2};
    }
  }

  Future<void> deleteUserData() async {
    final callable = functions.httpsCallable('deleteUserData');
    await callable.call();
  }
}
