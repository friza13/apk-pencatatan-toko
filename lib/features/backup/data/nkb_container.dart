import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'nkb_exceptions.dart';

/// Container layout (.nkb), little-endian:
///
///   magic   4 bytes  'NBK1'
///   manLen  4 bytes  uint32 length of manifest JSON (utf-8)
///   manifest         manifest JSON utf-8
///   blob             nonce(12) || AES-256-GCM(cipherText||tag)
///
/// Plain payload inside the GCM ciphertext is a ZIP archive containing:
///   database.sqlite  raw (sqlcipher-encrypted) database file
///   meta.json        `{"db_key": "<hex>"}` - DB key wrapped by backup password
class NkbContainer {
  NkbContainer._();

  static const List<int> magic = [0x4E, 0x42, 0x4B, 0x31]; // NBK1
  static const String formatName = 'notakit-backup';
  static const int formatVersion = 1;

  static Uint8List u32(int v) {
    final b = Uint8List(4);
    ByteData.sublistView(b).setUint32(0, v, Endian.little);
    return b;
  }

  static int readU32(Uint8List b, int offset) =>
      ByteData.sublistView(b, offset, offset + 4)
          .getUint32(0, Endian.little);

  static String sha256Hex(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();

  static Map<String, dynamic> buildManifest({
    required int schemaVersion,
    required String appVersion,
    required Map<String, int> recordCounts,
    required String saltHex,
    required String nonceHex,
    required int kdfIterations,
    required String checksumHex,
  }) =>
      {
        'format': formatName,
        'format_version': formatVersion,
        'schema_version': schemaVersion,
        'app_version': appVersion,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'cipher': 'AES-256-GCM',
        'kdf': {
          'algorithm': 'PBKDF2-HMAC-SHA256',
          'iterations': kdfIterations,
          'bits': 256,
        },
        'salt': saltHex,
        'nonce': nonceHex,
        'checksum_sha256': checksumHex,
        'compression': 'none',
        'payload': {'format': 'zip'},
        'record_counts': recordCounts,
      };

  /// Serializes header + manifest + encrypted blob.
  static Uint8List serialize({
    required Map<String, dynamic> manifest,
    required Uint8List encryptedBlob,
  }) {
    final manifestBytes =
        Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
    final out = BytesBuilder()
      ..add(magic)
      ..add(u32(manifestBytes.length))
      ..add(manifestBytes)
      ..add(encryptedBlob);
    return out.toBytes();
  }

  /// Parses raw container into manifest + encrypted blob with structural
  /// validation only (no crypto).
  static ({Map<String, dynamic> manifest, Uint8List blob}) parseRaw(
      Uint8List bytes) {
    if (bytes.length < 8 ||
        bytes[0] != magic[0] ||
        bytes[1] != magic[1] ||
        bytes[2] != magic[2] ||
        bytes[3] != magic[3]) {
      throw const BackupFormatException('File bukan backup NotaKit (.nkb).');
    }
    final manLen = readU32(bytes, 4);
    if (manLen <= 0 || 8 + manLen >= bytes.length) {
      throw const BackupFormatException('Manifest rusak.');
    }
    final manifestJson =
        utf8.decode(bytes.sublist(8, 8 + manLen));
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    final blob = Uint8List.fromList(bytes.sublist(8 + manLen));
    return (manifest: manifest, blob: blob);
  }

}

typedef RandomSource = List<int> Function(int byteCount);
