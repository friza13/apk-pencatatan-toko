import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// NotaKit material themes — light first; dark must not break (DESAIN.md §50).
abstract final class AppTheme {
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: AppColors.primary600,
    primaryContainer: AppColors.primary100,
    onPrimaryContainer: AppColors.primary900,
    secondary: AppColors.accent600,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.accent100,
    onSecondaryContainer: AppColors.accent700,
    error: AppColors.danger600,
    errorContainer: AppColors.danger100,
    onErrorContainer: AppColors.danger700,
    onSurface: AppColors.neutral900,
    surfaceContainerHighest: AppColors.neutral100,
    onSurfaceVariant: AppColors.neutral600,
    outline: AppColors.neutral300,
    outlineVariant: AppColors.neutral200,
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: AppColors.primaryDarkMode,
    onPrimary: AppColors.neutral950,
    primaryContainer: AppColors.primary800,
    onPrimaryContainer: AppColors.primary50,
    secondary: AppColors.accent500,
    onSecondary: AppColors.neutral950,
    secondaryContainer: AppColors.accent700,
    onSecondaryContainer: AppColors.accent50,
    error: AppColors.danger500,
    onError: AppColors.neutral950,
    errorContainer: AppColors.danger700,
    onErrorContainer: AppColors.danger50,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    surfaceContainerHighest: AppColors.darkSurfaceElevated,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkDivider,
    outlineVariant: AppColors.darkDivider,
  );

  static ThemeData light() => _base(lightColorScheme, AppColors.neutral50);

  static ThemeData dark() => _base(darkColorScheme, AppColors.darkBackground);

  static ThemeData _base(ColorScheme scheme, Color scaffoldBackground) {
    final bool isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: AppTypography.fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: isDark
            ? AppColors.darkTextPrimary
            : AppColors.neutral900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.neutral900,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.neutral200,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: AppTypography.title.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor:
            isDark ? AppColors.darkSurfaceElevated : AppColors.neutral100,
        selectedColor: isDark ? AppColors.primary800 : AppColors.primary100,
        side: BorderSide(
          color: isDark ? AppColors.darkDivider : AppColors.neutral300,
        ),
        labelStyle: AppTypography.caption.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.neutral800,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: AppTypography.caption.copyWith(
          color: isDark ? AppColors.primary50 : AppColors.primary900,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTextPrimary : AppColors.neutral700,
          size: 18,
        ),
        checkmarkColor: isDark ? AppColors.primary50 : AppColors.primary900,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.neutral100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.caption.copyWith(color: scheme.onSurface),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
      dividerColor: isDark ? AppColors.darkDivider : AppColors.neutral200,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
