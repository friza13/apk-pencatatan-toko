import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/security/pin_hasher.dart';
import 'package:notakit/core/security/secure_store.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/security/auth_controller.dart';
import 'package:notakit/features/security/auth_repository.dart';
import 'package:notakit/features/security/providers.dart';

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

class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({this.available = false, this.result = false});

  bool available;
  bool result;
  int promptCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    promptCount++;
    return result;
  }
}

void main() {
  late AppDatabase db;
  late InMemorySecureStore secure;
  late FakeBiometric biometric;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    secure = InMemorySecureStore();
    biometric = FakeBiometric();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
      secureStoreProvider.overrideWithValue(secure),
      biometricAuthProvider.overrideWithValue(biometric),
      pinHasherProvider.overrideWith((ref) => const PinHasher(iterations: 1000)),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  Future<AuthState> readState() =>
      container.read(authControllerProvider.future);

  test('fresh install resolves to needsOnboarding', () async {
    expect((await readState()).phase, AuthPhase.needsOnboarding);
  });

  test('onboard unlocks; lock() locks again', () async {
    await container
        .read(authControllerProvider.notifier)
        .onboard(ownerName: 'A', businessName: 'Toko', pin: '123456');

    expect((await readState()).phase, AuthPhase.unlocked);

    container.read(authControllerProvider.notifier).lock();
    expect((await readState()).phase, AuthPhase.locked);
  });

  test('unlockWithPin wrong then right', () async {
    final notifier = container.read(authControllerProvider.notifier);
    await notifier.onboard(ownerName: 'A', businessName: 'Toko', pin: '123456');
    notifier.lock();

    expect(await notifier.unlockWithPin('000000'), UnlockResult.wrongPin);
    expect((await readState()).phase, AuthPhase.locked);

    expect(await notifier.unlockWithPin('123456'), UnlockResult.success);
    expect((await readState()).phase, AuthPhase.unlocked);
  });

  test('biometric only usable when available AND enabled', () async {
    final notifier = container.read(authControllerProvider.notifier);
    await notifier.onboard(ownerName: 'A', businessName: 'Toko', pin: '123456');
    notifier.lock();

    // Not enabled yet.
    expect(
      await notifier.unlockWithBiometric(),
      UnlockResult.notAvailable,
    );
    expect(biometric.promptCount, 0);

    await AuthRepository(db: db, secureStore: secure).setBiometricEnabled(true);
    biometric.available = true;

    // Rebuild state from storage.
    container.invalidate(authControllerProvider);
    final s = await readState();
    expect(s.canUseBiometric, isTrue);

    biometric.result = false;
    expect(
      await notifier.unlockWithBiometric(),
      UnlockResult.wrongPin,
    );

    biometric.result = true;
    expect(await notifier.unlockWithBiometric(), UnlockResult.success);
    expect((await readState()).phase, AuthPhase.unlocked);
  });
}
