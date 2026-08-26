/// Exceptions for the .nkb container (P10).
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when AEAD verification fails - wrong password or tampered file.
class BackupWrongPasswordException implements Exception {
  const BackupWrongPasswordException();

  @override
  String toString() => 'Password salah atau file rusak.';
}
