class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool emailVerified;

  factory AppUser.fromFirebase(dynamic firebaseUser) {
    return AppUser(
      uid: firebaseUser.uid as String,
      email: (firebaseUser.email as String?) ?? '',
      displayName: (firebaseUser.displayName as String?) ?? 'Shopper',
      photoUrl: firebaseUser.photoURL as String?,
      emailVerified: (firebaseUser.emailVerified as bool?) ?? false,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
