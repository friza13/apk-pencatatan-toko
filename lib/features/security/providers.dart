import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/security/secure_store.dart';
import '../../database/app_database.dart';

/// Production [SecureStore] backed by flutter_secure_storage
/// (Android Keystore-wrapped).
final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>((ref) {
  // flutter_secure_storage v11 defaults to the strongest Android-backed
  // storage (Keystore/EncryptedSharedPreferences successor).
  return FlutterSecureStoreAdapter(const FlutterSecureStorage());
});

class FlutterSecureStoreAdapter implements SecureStore {
  FlutterSecureStoreAdapter(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Production biometric gate backed by local_auth.
final Provider<BiometricAuthenticator> biometricAuthProvider =
    Provider<BiometricAuthenticator>((ref) {
  return LocalAuthAdapter(LocalAuthentication());
});

class LocalAuthAdapter implements BiometricAuthenticator {
  LocalAuthAdapter(this._auth);

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async =>
      await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

  @override
  Future<bool> authenticate({required String reason}) =>
      _auth.authenticate(localizedReason: reason);
}

/// Opens the encrypted production database; creates the random DB key on
/// first launch (D-022). Key lives in secure storage, never in code.
final FutureProvider<AppDatabase> appDatabaseProvider =
    FutureProvider<AppDatabase>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  final file = File('${docs.path}/notakit.db');

  final secure = ref.watch(secureStoreProvider);
  var passphrase = await secure.read('nk.db.key');
  if (passphrase == null || passphrase.isEmpty) {
    passphrase = _randomKey();
    await secure.write('nk.db.key', passphrase);
  }

  final db = AppDatabase(openEncryptedExecutor(
    file: file,
    passphrase: passphrase,
  ));
  ref.onDispose(db.close);
  return db;
});

String _randomKey() {
  final rng = Random.secure();
  return List<int>.generate(32, (_) => rng.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
