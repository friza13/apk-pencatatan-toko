import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Crypto primitives for the .nkb container (D-004/D-019):
/// AES-256-GCM authenticated encryption, PBKDF2-HMAC-SHA256 key derivation
/// with parameters carried in the manifest (algorithm-agile).
class BackupCrypto {
  BackupCrypto._();

  static const String kdfAlgo = 'PBKDF2-HMAC-SHA256';
  static const int defaultIterations = 600000;
  static const int keyBits = 256;
  static const int saltBytes = 16;
  static const int nonceBytes = 12;

  static Future<Uint8List> deriveKey({
    required String password,
    required Uint8List salt,
    required int iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: keyBits,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// AES-256-GCM encrypt. Returns nonce(12) || cipherText+tag.
  static Future<Uint8List> encrypt({
    required Uint8List key,
    required Uint8List nonce,
    required List<int> plain,
  }) async {
    final algo = AesGcm.with256bits();
    final secretBox = await algo.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final out = BytesBuilder()
      ..add(secretBox.nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);
    return out.toBytes();
  }

  /// Decrypts nonce(12)||cipherText+tag. Throws on tamper/wrong key.
  static Future<List<int>> decrypt({
    required Uint8List key,
    required Uint8List blob,
  }) async {
    if (blob.length < nonceBytes + 16) {
      throw const FormatException('Encrypted backup payload is truncated.');
    }
    final algo = AesGcm.with256bits();
    final nonce = blob.sublist(0, nonceBytes);
    final cipherText = blob.sublist(nonceBytes, blob.length - 16);
    final mac = Mac(blob.sublist(blob.length - 16));

    final clear = await algo.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: SecretKey(key),
    );
    return clear;
  }
}

/// Small helpers shared by container code.
class NkbBytes {
  NkbBytes._();

  static Uint8List fromUtf8(String s) => Uint8List.fromList(utf8.encode(s));

  static String toUtf8(List<int> b) => utf8.decode(b);

  static List<int> unhex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
