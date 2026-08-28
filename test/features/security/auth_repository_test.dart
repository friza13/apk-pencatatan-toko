import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/security/pin_hasher.dart';
import 'package:notakit/core/security/secure_store.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/security/auth_repository.dart';

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

void main() {
  late AppDatabase db;
  late AuthRepository repo;
  late InMemorySecureStore secure;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    secure = InMemorySecureStore();
    repo = AuthRepository(
      db: db,
      secureStore: secure,
      hasher: const PinHasher(iterations: 1000),
    );
  });

  tearDown(() async => db.close());

  test(
    'fresh install is not onboarded; ensureDbKey creates persistent key',
    () async {
      expect(await repo.isOnboarded(), isFalse);
      final key1 = await repo.ensureDbKey();
      final key2 = await repo.ensureDbKey();
      expect(key1, key2, reason: 'key must be created once');
      expect(key1.length, 64);
    },
  );

  test('onboard creates owner+business and PIN verifier', () async {
    await repo.onboard(
      ownerName: 'Budi',
      businessName: 'Toko Budi',
      pin: '123456',
    );

    expect(await repo.isOnboarded(), isTrue);
    expect(await repo.verifyPin('123456'), isTrue);
    expect(await repo.verifyPin('000000'), isFalse);
    expect(await repo.biometricEnabled(), isFalse);

    final business = await repo.currentBusiness();
    expect(business?.name, 'Toko Budi');
  });

  test('second onboard is rejected (single owner)', () async {
    await repo.onboard(ownerName: 'A', businessName: 'Toko A', pin: '111111');
    expect(
      () => repo.onboard(ownerName: 'B', businessName: 'Toko B', pin: '222222'),
      throwsStateError,
    );
  });

  test('PIN validation rejects non-6-digit pins', () {
    // Terlalu pendek (4 digit — aturan baru: tepat 6).
    expect(
      () => repo.onboard(ownerName: 'A', businessName: 'T', pin: '1234'),
      throwsArgumentError,
    );
    expect(
      () => repo.onboard(ownerName: 'A', businessName: 'T', pin: '12345'),
      throwsArgumentError,
    );
    // Kelebihan digit.
    expect(
      () => repo.onboard(ownerName: 'A', businessName: 'T', pin: '1234567'),
      throwsArgumentError,
    );
    // Bukan angka.
    expect(
      () => repo.onboard(ownerName: 'A', businessName: 'T', pin: '12ab56'),
      throwsArgumentError,
    );
  });

  test('changePin requires correct old pin', () async {
    await repo.onboard(ownerName: 'A', businessName: 'T', pin: '111111');
    expect(
      () => repo.changePin(oldPin: '999999', newPin: '222222'),
      throwsArgumentError,
    );

    await repo.changePin(oldPin: '111111', newPin: '222222');
    expect(await repo.verifyPin('111111'), isFalse);
    expect(await repo.verifyPin('222222'), isTrue);
  });

  test('biometric flag toggles', () async {
    await repo.onboard(ownerName: 'A', businessName: 'T', pin: '111111');
    await repo.setBiometricEnabled(true);
    expect(await repo.biometricEnabled(), isTrue);
    await repo.setBiometricEnabled(false);
    expect(await repo.biometricEnabled(), isFalse);
  });

  test('updateBusinessProfile writes fields', () async {
    final businessId = await repo.onboard(
      ownerName: 'A',
      businessName: 'Old Name',
      pin: '111111',
    );
    await repo.updateBusinessProfile(
      businessId: businessId,
      name: 'New Name',
      address: const Value('Jl. Merdeka 10'),
      footerNote: const Value('Terima kasih'),
    );
    final b = await repo.currentBusiness();
    expect(b!.name, 'New Name');
    expect(b.address, 'Jl. Merdeka 10');
    expect(b.footerNote, 'Terima kasih');
  });
}
