import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/app/theme/app_colors.dart';
import 'package:notakit/app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses NotaKit Indigo primary', () {
      expect(AppTheme.light().colorScheme.primary, const Color(0xFF2563EB));
    });

    test('dark theme uses dark background and adjusted primary', () {
      final ThemeData dark = AppTheme.dark();
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0B1220));
      expect(dark.colorScheme.primary, const Color(0xFF60A5FA));
    });

    test('themes declare Inter as font family', () {
      expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily, 'Inter');
    });

    test('light and dark themes build without error', () {
      expect(AppTheme.light(), isA<ThemeData>());
      expect(AppTheme.dark(), isA<ThemeData>());
    });

    test('chipTheme declares high-contrast text and border colors in light and dark mode', () {
      final light = AppTheme.light().chipTheme;
      expect(light.labelStyle?.color, AppColors.neutral800);
      expect(light.secondaryLabelStyle?.color, AppColors.primary900);
      expect(light.backgroundColor, AppColors.neutral100);
      expect(light.selectedColor, AppColors.primary100);
      expect(light.side?.color, AppColors.neutral300);

      final dark = AppTheme.dark().chipTheme;
      expect(dark.labelStyle?.color, AppColors.darkTextPrimary);
      expect(dark.secondaryLabelStyle?.color, AppColors.primary50);
      expect(dark.backgroundColor, AppColors.darkSurfaceElevated);
      expect(dark.selectedColor, AppColors.primary800);
      expect(dark.side?.color, AppColors.darkDivider);
    });

    testWidgets('ActionChip and FilterChip render with sharp legible text colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add_shopping_cart),
                  label: const Text('Buat Nota'),
                  onPressed: () {},
                ),
                FilterChip(
                  label: const Text('Aktif'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Semua'),
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Buat Nota'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
    });
  });
}
