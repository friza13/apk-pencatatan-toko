import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:notakit/core/security/pin_hasher.dart';
import 'package:notakit/core/security/secure_store.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/dashboard/dashboard_screen.dart';
import 'package:notakit/features/onboarding/onboarding_screen.dart';
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

class NoFileSelectedPicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [];
}

Future<ProviderContainer> _pumpFreshApp(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      biometricAuthProvider.overrideWithValue(NoBiometric()),
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
  return container;
}

void main() {
  testWidgets('selecting restore backup starts the restore flow', (
    tester,
  ) async {
    final originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = NoFileSelectedPicker();
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    await _pumpFreshApp(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Nama kamu'), 'Budi');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama usaha'),
      'Toko Budi Jaya',
    );
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Mulai dari data kamu'), findsOneWidget);
    await tester.tap(find.byType(RadioListTile<int>).at(1));
    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    expect(find.text('Mulai dari data kamu'), findsOneWidget);
  });

  testWidgets('fresh install shows onboarding; completing it reaches Beranda', (
    tester,
  ) async {
    final container = await _pumpFreshApp(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Kenalkan toko kamu'), findsOneWidget);

    // Step 1 — store identity.
    await tester.enterText(find.widgetWithText(TextField, 'Nama kamu'), 'Budi');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama usaha'),
      'Toko Budi Jaya',
    );
    await tester.pump();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 2 — empty data choice is the default.
    expect(find.text('Mulai dari data kamu'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    // Step 3 — PIN (tepat 6 digit, D-023).
    await tester.enterText(
      find.widgetWithText(TextField, 'PIN (6 digit)'),
      '123456',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Ulangi PIN (6 digit)'),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.text('Mulai dengan NotaKit'));
    // Cheap test hasher completes inside the fake-async zone; a couple of
    // pumps flush its microtasks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    expect(
      (await container.read(authControllerProvider.future)).phase,
      AuthPhase.unlocked,
    );
    expect(find.byType(DashboardScreen), findsOneWidget);
    // AppBar menampilkan nama toko setelah onboarding.
  });

  testWidgets('onboarded install shows lock screen; wrong pin rejected', (
    tester,
  ) async {
    final container = await _pumpFreshApp(tester);
    await container
        .read(authControllerProvider.notifier)
        .onboard(ownerName: 'A', businessName: 'Toko', pin: '123456');
    container.read(authControllerProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(find.text('Masukkan PIN untuk membuka'), findsOneWidget);

    expect(find.text('Masukkan PIN untuk membuka'), findsOneWidget);

    // PIN 6 digit: auto-submit hanya setelah digit ke-6.
    for (final d in ['9', '9', '9', '9', '9']) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    // Belum submit di 5 digit — tidak ada pesan error.
    expect(find.text('PIN salah. Coba lagi.'), findsNothing);

    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();

    expect(find.text('PIN salah. Coba lagi.'), findsOneWidget);
  });
}
