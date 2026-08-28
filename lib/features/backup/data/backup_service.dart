import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../database/app_database.dart';
import 'backup_crypto.dart';
import 'nkb_container.dart';
import 'nkb_exceptions.dart';

/// High-level backup/restore orchestration (P10).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Creates an encrypted .nkb file from a consistent VACUUM snapshot.
  Future<File> createBackup({
    required String sourceDbPath,
    required String saveToPath,
    required String password,
    required int schemaVersion,
    required String appVersion,
    required Map<String, int> recordCounts,
    required String dbKeyHex,
    required String dbPassphrase,
    int kdfIterations = BackupCrypto.defaultIterations,
  }) async {
    // Consistent snapshot via VACUUM INTO on the live connection.
    final tmpSnap = File(
      '$sourceDbPath.backup-${DateTime.now().millisecondsSinceEpoch}.tmp',
    );
    final exists = await tmpSnap.exists();
    if (exists) {
      await tmpSnap.delete();
    }
    await _db.customStatement('VACUUM INTO ?', [tmpSnap.path]);

    try {
      final rng = Random.secure();
      final salt = Uint8List.fromList(
        List.generate(BackupCrypto.saltBytes, (_) => rng.nextInt(256)),
      );
      final nonce = Uint8List.fromList(
        List.generate(BackupCrypto.nonceBytes, (_) => rng.nextInt(256)),
      );

      final key = await BackupCrypto.deriveKey(
        password: password,
        salt: salt,
        iterations: kdfIterations,
      );

      final archive = Archive();
      final dbBytes = await tmpSnap.readAsBytes();
      archive.addFile(ArchiveFile('database.sqlite', dbBytes.length, dbBytes));
      final metaJson = jsonEncode({'db_key': dbKeyHex});
      final metaBytes = NkbBytes.fromUtf8(metaJson);
      archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));
      final zipped = ZipEncoder().encode(archive);

      final encrypted = await BackupCrypto.encrypt(
        key: key,
        nonce: nonce,
        plain: zipped,
      );
      final manifest = NkbContainer.buildManifest(
        schemaVersion: schemaVersion,
        appVersion: appVersion,
        recordCounts: recordCounts,
        saltHex: NkbBytes.hex(salt),
        nonceHex: NkbBytes.hex(nonce),
        kdfIterations: kdfIterations,
        checksumHex: NkbContainer.sha256Hex(encrypted),
      );

      final file = File(saveToPath);
      await file.writeAsBytes(
        NkbContainer.serialize(manifest: manifest, encryptedBlob: encrypted),
      );
      return file;
    } finally {
      if (await tmpSnap.exists()) {
        await tmpSnap.delete();
      }
    }
  }

  /// Validates container + password; returns preview without touching target.
  Future<RestorePreview> inspect({
    required File nkbFile,
    required String password,
  }) async {
    final bytes = await nkbFile.readAsBytes();
    final parsed = NkbContainer.parseRaw(bytes);
    var manifest = parsed.manifest;

    _verifyChecksum(parsed.blob, manifest);
    if (parsed.blob.length < BackupCrypto.nonceBytes + 16) {
      throw const BackupFormatException('Payload backup tidak lengkap.');
    }

    final kdfMap = manifest['kdf'];
    final iterations = kdfMap is Map
        ? ((kdfMap['iterations'] as num?) ?? BackupCrypto.defaultIterations)
              .toInt()
        : BackupCrypto.defaultIterations;

    List<int> clear;
    try {
      final salt = Uint8List.fromList(
        Uint8List.fromList(NkbBytes.unhex(manifest['salt'] as String? ?? '')),
      );
      final key = await BackupCrypto.deriveKey(
        password: password,
        salt: salt,
        iterations: iterations,
      );
      clear = await BackupCrypto.decrypt(key: key, blob: parsed.blob);
    } on Object {
      throw const BackupWrongPasswordException();
    }

    final decoded = ZipDecoder().decodeBytes(clear);
    String dbKeyHex = '';
    Uint8List database = Uint8List(0);
    for (final f in decoded) {
      if (f.name == 'database.sqlite') {
        database = Uint8List.fromList(f.content as List<int>);
      } else if (f.name == 'meta.json') {
        final meta = jsonDecode(utf8.decode(f.content as List<int>)) as Map;
        dbKeyHex = meta['db_key']?.toString() ?? '';
      }
    }
    if (dbKeyHex.isEmpty || database.isEmpty) {
      throw const BackupFormatException('Payload backup tidak lengkap.');
    }
    manifest = manifest;
    final schemaVersion = (manifest['schema_version'] as num?)?.toInt() ?? 0;
    if (schemaVersion > _db.schemaVersion) {
      throw BackupFormatException(
        'Backup dari versi aplikasi lebih baru. Perbarui aplikasi.',
      );
    }

    return RestorePreview(
      createdAtIso: manifest['created_at']?.toString() ?? '',
      schemaVersion: schemaVersion,
      recordCounts: _intMap(manifest['record_counts']),
      databaseBytes: database,
      dbKeyHex: dbKeyHex,
    );
  }

  /// Stages decrypted DB to temp file, verifies integrity + completeness via
  /// a probe connection, then atomically swaps into [targetDbPath]. Caller
  /// must close/reopen connections around this call.
  Future<void> applyRestore({
    required RestorePreview preview,
    required String targetDbPath,
    required String dbPassphrase,
  }) async {
    final staging = File(
      '$targetDbPath.restore-${DateTime.now().millisecondsSinceEpoch}',
    );
    await staging.writeAsBytes(preview.databaseBytes, flush: true);

    final probe = AppDatabase(
      openEncryptedExecutor(file: staging, passphrase: dbPassphrase),
    );
    try {
      final okRow = await probe
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      final ok = okRow.data.values.first?.toString() ?? '';
      if (ok != 'ok') {
        throw BackupFormatException('Integrity check gagal: $ok');
      }
      final tables = await probe
          .customSelect(
            "SELECT count(*) AS c FROM sqlite_master WHERE type='table'",
          )
          .getSingle();
      if (((tables.data['c'] as int?) ?? 0) < 30) {
        throw const BackupFormatException(
          'Database hasil restore tidak lengkap.',
        );
      }
    } finally {
      await probe.close();
    }

    final target = File(targetDbPath);
    final previous = File(
      '$targetDbPath.previous-${DateTime.now().millisecondsSinceEpoch}',
    );
    var movedPrevious = false;
    try {
      if (await target.exists()) {
        await target.rename(previous.path);
        movedPrevious = true;
      }
      await staging.rename(target.path);
      if (movedPrevious && await previous.exists()) {
        await previous.delete();
      }
    } catch (_) {
      if (await staging.exists()) {
        await staging.delete();
      }
      if (movedPrevious && !await target.exists() && await previous.exists()) {
        await previous.rename(target.path);
      }
      rethrow;
    }
  }

  void _verifyChecksum(Uint8List blob, Map<String, dynamic> manifest) {
    final expected = manifest['checksum_sha256']?.toString();
    if (expected == null || expected != NkbContainer.sha256Hex(blob)) {
      throw const BackupFormatException(
        'Checksum tidak cocok. File korup atau dimodifikasi.',
      );
    }
  }

  Map<String, int> _intMap(Object? raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return {};
  }
}

/// Preview data shown to user before confirming destructive restore.
class RestorePreview {
  RestorePreview({
    required this.createdAtIso,
    required this.schemaVersion,
    required this.recordCounts,
    required this.databaseBytes,
    required this.dbKeyHex,
  });

  final String createdAtIso;
  final int schemaVersion;
  final Map<String, int> recordCounts;
  final Uint8List databaseBytes;
  final String dbKeyHex;
}
