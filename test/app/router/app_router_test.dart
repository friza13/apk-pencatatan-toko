import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:notakit/core/security/pin_hasher.dart';
import 'package:notakit/core/security/secure_store.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/security/auth_controller.dart';
import 'package:notakit/features/security/providers.dart';
import 'package:notakit/main.dart';

class InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class NoBiometric implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

Future<ProviderContainer> _pumpUnlockedApp(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  final secure = InMemorySecureStore();
  final biometric = NoBiometric();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
      secureStoreProvider.overrideWithValue(secure),
      biometricAuthProvider.overrideWithValue(biometric),
      pinHasherProvider.overrideWith(
        (ref) => const PinHasher(iterations: 1000),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const NotaKitApp()),
  );
  await tester.pumpAndSettle();

  // Skip onboarding straight to an unlocked session. The cheap test hasher
  // completes inside the fake-async zone.
  await container
      .read(authControllerProvider.notifier)
      .onboard(ownerName: 'A', businessName: 'Toko', pin: '123456');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('unlocked app shows Beranda with 5-tab bottom navigation', (
    tester,
  ) async {
    await _pumpUnlockedApp(tester);

    expect(find.text('Beranda'), findsAtLeastNWidgets(1));
    expect(find.text('Penjualan'), findsOneWidget);
    expect(find.text('Produk'), findsWidgets);
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
  });

  testWidgets('bottom navigation switches to Produk tab', (tester) async {
    final container = await _pumpUnlockedApp(tester);

    await tester.tap(find.text('Produk').last);
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(router.routerDelegate.currentConfiguration.uri.path, '/products');
    addTearDown(container.dispose);
  });

  testWidgets('bottom navigation opens the real reports screen', (
    tester,
  ) async {
    await _pumpUnlockedApp(tester);

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Omzet'), findsOneWidget);
    expect(find.text('Laporan akan hadir di sini.'), findsNothing);
  });
}
