import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// PIN verifier hashing (D-022).
///
/// The PIN itself is never stored. We store `salt + hash` where hash is
/// PBKDF2-HMAC-SHA256 (100k iterations). The primary protection for local
/// data is the Keystore-wrapped DB key and the encrypted database; this hash
/// is defense-in-depth against casual inspection of secure storage.
abstract final class PinHasher {
  static const int iterations = 100000;

  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  /// Generates a fresh random salt, hex-encoded (16 bytes), using the
  /// platform CSPRNG.
  static String newSalt() {
    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );
    return const HexCodec().encode(salt);
  }

  /// Computes the hex-encoded verifier for [pin] over [saltHex].
  static Future<String> hash(String pin, String saltHex) async {
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: pin,
      nonce: const HexCodec().decode(saltHex),
    );
    final bytes = await secretKey.extractBytes();
    return const HexCodec().encode(bytes);
  }
}

class HexCodec {
  const HexCodec();

  String encode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Uint8List decode(String hex) {
    if (hex.length.isOdd) {
      throw ArgumentError('odd-length hex');
    }
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// Verifies a PIN against stored salt+hash in constant time.
Future<bool> verifyPin({
  required String pin,
  required String saltHex,
  required String expectedHashHex,
}) async {
  final actual = await PinHasher.hash(pin, saltHex);
  return constantTimeEquals(actual, expectedHashHex);
}

bool constantTimeEquals(String a, String b) {
  final ab = utf8.encode(a);
  final bb = utf8.encode(b);
  var diff = ab.length ^ bb.length;
  final n = ab.length < bb.length ? ab.length : bb.length;
  for (var i = 0; i < n; i++) {
    diff |= ab[i] ^ bb[i];
  }
  return diff == 0;
}
