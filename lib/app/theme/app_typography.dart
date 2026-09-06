import 'package:flutter/material.dart';

/// NotaKit typography scale — source of truth: docs/DESAIN.md §5.
///
/// Inter is the intended brand font. Until the font files are bundled as
/// assets, [AppTypography.fontFamily] still declares 'Inter' so the app picks
/// it up automatically once bundled; until then Flutter falls back to the
/// platform system font.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    fontFamily: fontFamily,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
  );

  /// Tabular numbers for financial alignment in cashier POS and bookkeeping.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const TextStyle numberDisplay = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    fontFeatures: tabularFigures,
  );

  static const TextStyle numberLarge = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    fontFamily: fontFamily,
    fontFeatures: tabularFigures,
  );

  static const TextStyle numberMedium = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    fontFeatures: tabularFigures,
  );
}
