import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  /// Set to true in test suites to prevent unmocked HTTP font fetch attempts
  static bool isTest = false;

  // Headings (Fraunces Serif)
  static TextStyle get displayLarge => isTest
      ? const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -0.5,
        )
      : GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -0.5,
        );

  static TextStyle get displayMedium => isTest
      ? const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        )
      : GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        );

  static TextStyle get headlineMedium => isTest
      ? const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        )
      : GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        );

  static TextStyle get titleLarge => isTest
      ? const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        )
      : GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        );

  // Body & Labels (Inter Sans)
  static TextStyle get bodyLarge => isTest
      ? const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
          height: 1.5,
        )
      : GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
          height: 1.5,
        );

  static TextStyle get bodyMedium => isTest
      ? const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
          height: 1.4,
        )
      : GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
          height: 1.4,
        );

  static TextStyle get bodySmall => isTest
      ? const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMuted,
        )
      : GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMuted,
        );

  static TextStyle get labelLarge => isTest
      ? const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        )
      : GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

  static TextStyle get labelMedium => isTest
      ? const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        )
      : GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
}
