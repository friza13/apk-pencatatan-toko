import 'package:flutter/material.dart';

/// NotaKit color tokens — source of truth: docs/DESAIN.md §3–§4.
abstract final class AppColors {
  // Primary — NotaKit Indigo.
  static const Color primary900 = Color(0xFF172554);
  static const Color primary800 = Color(0xFF1E3A8A);
  static const Color primary700 = Color(0xFF1D4ED8);
  static const Color primary600 = Color(0xFF2563EB);
  static const Color primary500 = Color(0xFF3B82F6);
  static const Color primary100 = Color(0xFFDBEAFE);
  static const Color primary50 = Color(0xFFEFF6FF);

  // Accent — Mint (profit / success / safe stock).
  static const Color accent700 = Color(0xFF047857);
  static const Color accent600 = Color(0xFF059669);
  static const Color accent500 = Color(0xFF10B981);
  static const Color accent100 = Color(0xFFD1FAE5);
  static const Color accent50 = Color(0xFFECFDF5);

  // Warning — Amber.
  static const Color warning700 = Color(0xFFB45309);
  static const Color warning600 = Color(0xFFD97706);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color warning100 = Color(0xFFFEF3C7);
  static const Color warning50 = Color(0xFFFFFBEB);

  // Danger — Red.
  static const Color danger700 = Color(0xFFB91C1C);
  static const Color danger600 = Color(0xFFDC2626);
  static const Color danger500 = Color(0xFFEF4444);
  static const Color danger100 = Color(0xFFFEE2E2);
  static const Color danger50 = Color(0xFFFEF2F2);

  // Neutral.
  static const Color neutral950 = Color(0xFF0F172A);
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color white = Color(0xFFFFFFFF);

  // Dark mode surfaces (DESAIN.md §4).
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1F2937);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkDivider = Color(0xFF334155);

  /// Primary in dark mode keeps contrast clear (DESAIN.md §4).
  static const Color primaryDarkMode = Color(0xFF60A5FA);
}
