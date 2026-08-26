import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/security/pin_hasher.dart';
import '../../core/security/secure_store.dart';
import '../../database/app_database.dart';

/// Keys used inside [SecureStore].
abstract final class SecureKeys {
  static const dbKey = 'nk.db.key';
  static const pinSalt = 'nk.pin.salt';
  static const pinHash = 'nk.pin.hash';
  static const biometricEnabled = 'nk.biometric.enabled';
}

/// Owner authentication and bootstrap data (FR-AUTH-001/FR-STORE-001).
///
/// Security model D-022: the database key is random and Keystore-wrapped;
/// the PIN verifier lives only as a salted PBKDF2 hash.
// Private fields cannot be named parameters, so initializing formals are
// impossible here; suppress the style lint for this repository class.
// ignore_for_file: prefer_initializing_formals
class AuthRepository {
  AuthRepository({
    required AppDatabase db,
    required SecureStore secureStore,
    this.hasher = const PinHasher(),
  })  : _db = db,
        _secure = secureStore;

  final AppDatabase _db;
  final SecureStore _secure;

  /// Injectable for tests (cheap iterations) — production keeps the default.
  final PinHasher hasher;

  Future<bool> isOnboarded() async {
    final rows = await _db.select(_db.owners).get();
    return rows.isNotEmpty;
  }

  /// Returns the existing database passphrase or creates a fresh random one.
  Future<String> ensureDbKey() async {
    var key = await _secure.read(SecureKeys.dbKey);
    if (key == null || key.isEmpty) {
      key = _randomHex(32);
      await _secure.write(SecureKeys.dbKey, key);
    }
    return key;
  }

  /// Creates the single owner + business + PIN verifier. Refuses when an
  /// owner already exists (single-owner application).
  Future<int> onboard({
    required String ownerName,
    required String businessName,
    required String pin,
    String timezone = 'Asia/Jakarta',
  }) async {
    if (await isOnboarded()) {
      throw StateError('Owner already onboarded');
    }
    _validatePin(pin);

    final ownerId = await _db.into(_db.owners).insert(
          OwnersCompanion.insert(name: ownerName),
        );
    final businessId = await _db.into(_db.businesses).insert(
          BusinessesCompanion.insert(
            ownerId: ownerId,
            name: businessName,
            timezone: Value(timezone),
          ),
        );

    await _writePinVerifier(pin);
    await _secure.write(SecureKeys.biometricEnabled, 'false');
    return businessId;
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _secure.read(SecureKeys.pinSalt);
    final stored = await _secure.read(SecureKeys.pinHash);
    if (salt == null || stored == null) {
      return false;
    }
    return verifyPinHash(
      hasher: hasher,
      pin: pin,
      saltHex: salt,
      expectedHashHex: stored,
    );
  }

  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (!await verifyPin(oldPin)) {
      throw ArgumentError.value(oldPin, 'oldPin', 'PIN lama salah');
    }
    _validatePin(newPin);
    await _writePinVerifier(newPin);
  }

  Future<bool> biometricEnabled() async =>
      await _secure.read(SecureKeys.biometricEnabled) == 'true';

  Future<void> setBiometricEnabled(bool enabled) =>
      _secure.write(SecureKeys.biometricEnabled, enabled ? 'true' : 'false');

  Future<Business?> currentBusiness() async {
    // NOTE: do NOT use `.limit(1)` here — it triggers a type-inference bug
    // in analyzer 12 + drift_dev 2.34.0 ("_db has type void"). The table is
    // tiny (single business), so fetching all rows and taking the first is
    // equivalent.
    final rows = await _db.select(_db.businesses).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateBusinessProfile({
    required int businessId,
    String? name,
    Value<String> address = const Value.absent(),
    Value<String> phone = const Value.absent(),
    Value<String> footerNote = const Value.absent(),
    Value<String> invoicePrefix = const Value.absent(),
  }) async {
    await (_db.update(_db.businesses)..where((t) => t.id.equals(businessId)))
        .write(BusinessesCompanion(
      name: name == null ? const Value.absent() : Value(name),
      address: address,
      phone: phone,
      footerNote: footerNote,
      invoicePrefix: invoicePrefix,
    ));
  }

  Future<void> _writePinVerifier(String pin) async {
    final salt = hasher.newSalt();
    final hash = await hasher.hash(pin, salt);
    await _secure.write(SecureKeys.pinSalt, salt);
    await _secure.write(SecureKeys.pinHash, hash);
  }

  void _validatePin(String pin) {
    // Owner decision (D-023): PIN is always exactly 6 digits, like bank PINs.
    final ok = pin.length == 6 && _digitsOnly(pin);
    if (!ok) {
      throw ArgumentError('PIN harus tepat 6 digit angka');
    }
  }

  bool _digitsOnly(String s) => RegExp(r'^\d+$').hasMatch(s);

  String _randomHex(int byteCount) {
    final rng = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
