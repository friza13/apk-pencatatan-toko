import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
