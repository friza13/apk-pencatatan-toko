/// Platform-agnostic secure storage contract (NFR-003).
///
/// Production implementation wraps flutter_secure_storage (Android
/// Keystore-backed). Domain and controllers depend on this interface only,
/// keeping them testable with in-memory fakes.
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<bool> containsKey(String key);
}

/// Biometric gate contract backed by local_auth in production.
abstract interface class BiometricAuthenticator {
  /// Whether the device has enrolled biometrics.
  Future<bool> isAvailable();

  /// Prompts the user; returns true when authentication succeeded.
  Future<bool> authenticate({required String reason});
}
