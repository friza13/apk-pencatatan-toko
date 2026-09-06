import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/app/auth_gate.dart';
import 'package:notakit/features/security/auth_controller.dart';

void main() {
  group('AuthGate Error & Retry Handling', () {
    testWidgets(
      'displays error message, technical details, and retry button when initialization fails',
      (tester) async {
        var retried = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => _MockFailingAuthController(
                  onRetryCalled: () => retried = true,
                ),
              ),
            ],
            child: MaterialApp(
              home: AuthGate(
                unlockedBuilder: (_) => const Scaffold(
                  body: Text('Main App Unlocked'),
                ),
              ),
            ),
          ),
        );

        // Wait for AsyncNotifier error state to resolve into the widget tree
        await tester.pumpAndSettle();

        // Error message must be visible
        expect(
          find.textContaining('Terjadi kesalahan saat memuat data toko'),
          findsOneWidget,
        );

        // "Coba Lagi" retry button must be visible
        expect(find.text('Coba Lagi'), findsOneWidget);

        // Expandable error detail button must be visible
        expect(find.text('Lihat Detail Kesalahan'), findsOneWidget);
        expect(
          find.textContaining('KeyStore initialization delay on Android 10'),
          findsNothing,
        );

        // Tap "Lihat Detail Kesalahan" to reveal technical error
        await tester.tap(find.text('Lihat Detail Kesalahan'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('KeyStore initialization delay on Android 10'),
          findsOneWidget,
        );

        // Tap "Coba Lagi"
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(retried, isTrue);
      },
    );
  });
}

class _MockFailingAuthController extends AuthController {
  _MockFailingAuthController({required this.onRetryCalled});

  final VoidCallback onRetryCalled;

  @override
  Future<AuthState> build() async {
    onRetryCalled();
    throw Exception('KeyStore initialization delay on Android 10');
  }
}
