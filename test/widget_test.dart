import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocease/core/constants/app_constants.dart';
import 'package:grocease/core/theme/app_colors.dart';
import 'package:grocease/core/theme/app_theme.dart';
import 'package:grocease/core/theme/app_typography.dart';
import 'package:grocease/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';

void main() {
  setUpAll(() {
    AppTypography.isTest = true;
  });

  group('Milestone 1 Tests', () {
    test('Design system color tokens match specification', () {
      expect(AppColors.paper, const Color(0xFFF6F2E9));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.ink, const Color(0xFF20261F));
      expect(AppColors.inkMuted, const Color(0xFF5B6459));
      expect(AppColors.forest, const Color(0xFF1F4C3D));
      expect(AppColors.moss, const Color(0xFF3D7A5D));
      expect(AppColors.sage, const Color(0xFFE7EFE6));
      expect(AppColors.line, const Color(0xFFD8D0BE));
      expect(AppColors.lineGreen, const Color(0xFFC3D6C6));
      expect(AppColors.gold, const Color(0xFFA97A1F));
      expect(AppColors.rust, const Color(0xFF9C4B3E));
      expect(AppColors.primaryButton, const Color(0xFF0F0F0F));
    });

    test('AppTheme generates light theme with correct tokens', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppColors.paper);
      expect(theme.colorScheme.primary, AppColors.forest);
      expect(theme.colorScheme.error, AppColors.rust);
      expect(theme.useMaterial3, isTrue);
    });

    testWidgets('SplashScreen renders GrocEase brand and tagline elements', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify cart and initial elements exist in widget tree
      expect(find.text('🛒'), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(AppConstants.appTagline), findsOneWidget);

      // Advance animation halfway
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('🍏'), findsOneWidget);
    });
  });
}
