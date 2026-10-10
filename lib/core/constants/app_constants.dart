class AppConstants {
  const AppConstants._();

  static const String appName = 'GrocEase';
  static const String appTagline = 'Shop together. Split smarter.';

  // Inactivity timeout: 3 minutes
  static const Duration inactivityTimeout = Duration(minutes: 3);

  // Email verification cooldown: 60 seconds
  static const Duration emailVerificationCooldown = Duration(seconds: 60);

  // Failed login lockout
  static const int maxFailedAttempts = 3;
  static const Duration lockoutDuration = Duration(minutes: 10);

  // Join code length
  static const int joinCodeLength = 6;
}
