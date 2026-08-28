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
    final tmpSnap = File(
      '$sourceDbPath.backup-${DateTime.now().millisecondsSinceEpoch}.tmp',
    );
    if (await tmpSnap.exists()) {
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
      final metaBytes = NkbBytes.fromUtf8(jsonEncode({'db_key': dbKeyHex}));
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
    final parsed = NkbContainer.parseRaw(await nkbFile.readAsBytes());
    _verifyChecksum(parsed.blob, parsed.manifest);
    final cryptoParameters = _validateManifest(parsed.manifest, parsed.blob);

    final key = await BackupCrypto.deriveKey(
      password: password,
      salt: cryptoParameters.salt,
      iterations: cryptoParameters.iterations,
    );
    List<int> clear;
    try {
      clear = await BackupCrypto.decrypt(key: key, blob: parsed.blob);
    } on Object {
      throw const BackupWrongPasswordException();
    }

    final List<ArchiveFile> decoded;
    try {
      decoded = ZipDecoder().decodeBytes(clear).files;
    } on Object {
      throw const BackupFormatException('Payload backup bukan ZIP yang valid.');
    }
    String? dbKeyHex;
    Uint8List? database;
    for (final file in decoded) {
      if (file.name == 'database.sqlite') {
        database = Uint8List.fromList(file.content as List<int>);
      } else if (file.name == 'meta.json') {
        try {
          final meta = jsonDecode(utf8.decode(file.content as List<int>));
          if (meta is Map) {
            dbKeyHex = meta['db_key']?.toString();
          }
        } on Object {
          throw const BackupFormatException('Metadata backup rusak.');
        }
      }
    }
    if (dbKeyHex == null ||
        !_isHexKey(dbKeyHex) ||
        database == null ||
        database.isEmpty) {
      throw const BackupFormatException('Payload backup tidak lengkap.');
    }

    final schemaVersion = _intField(parsed.manifest, 'schema_version');
    if (schemaVersion == null || schemaVersion > _db.schemaVersion) {
      throw BackupFormatException(
        'Backup dari versi aplikasi lebih baru. Perbarui aplikasi.',
      );
    }
    return RestorePreview(
      createdAtIso: parsed.manifest['created_at']?.toString() ?? '',
      schemaVersion: schemaVersion,
      recordCounts: _intMap(parsed.manifest['record_counts']),
      databaseBytes: database,
      dbKeyHex: dbKeyHex,
    );
  }

  /// Stages decrypted DB, validates it, then performs a recoverable swap.
  Future<void> applyRestore({
    required RestorePreview preview,
    required String targetDbPath,
    required String dbPassphrase,
  }) async {
    final stagingPath =
        '$targetDbPath.restore-${DateTime.now().microsecondsSinceEpoch}';
    final staging = File(stagingPath);
    final previousPath =
        '$targetDbPath.previous-${DateTime.now().microsecondsSinceEpoch}';
    final previousFiles = <({String current, String previous})>[];
    var installed = false;

    try {
      await _cleanupSidecars(stagingPath);
      await staging.writeAsBytes(preview.databaseBytes, flush: true);
      await _validateDatabaseFile(staging, dbPassphrase);
      await _cleanupSidecars(stagingPath);

      for (final suffix in ['', '-wal', '-shm']) {
        final currentPath = '$targetDbPath$suffix';
        final current = File(currentPath);
        if (await current.exists()) {
          final previous = File('$previousPath$suffix');
          await current.rename(previous.path);
          previousFiles.add((current: current.path, previous: previous.path));
        }
      }

      await staging.rename(targetDbPath);
      installed = true;
      await _validateDatabaseFile(File(targetDbPath), dbPassphrase);

      for (final file in previousFiles) {
        final old = File(file.previous);
        if (await old.exists()) {
          await old.delete();
        }
      }
    } catch (_) {
      if (installed) {
        await _deleteDatabaseFiles(targetDbPath);
      }
      for (final file in previousFiles.reversed) {
        final old = File(file.previous);
        if (await old.exists()) {
          await old.rename(file.current);
        }
      }
      rethrow;
    } finally {
      if (!installed) {
        await _deleteDatabaseFiles(stagingPath);
      } else {
        await _cleanupSidecars(stagingPath);
      }
    }
  }

  ({Uint8List salt, int iterations}) _validateManifest(
    Map<String, dynamic> manifest,
    Uint8List blob,
  ) {
    if (manifest['format'] != NkbContainer.formatName ||
        manifest['format_version'] != NkbContainer.formatVersion ||
        manifest['cipher'] != 'AES-256-GCM' ||
        manifest['compression'] != 'none' ||
        (manifest['payload'] is! Map ||
            (manifest['payload'] as Map)['format'] != 'zip')) {
      throw const BackupFormatException(
        'Parameter manifest backup tidak didukung.',
      );
    }
    final kdf = manifest['kdf'];
    if (kdf is! Map ||
        kdf['algorithm'] != BackupCrypto.kdfAlgo ||
        kdf['bits'] != 256) {
      throw const BackupFormatException('Parameter KDF backup tidak didukung.');
    }
    final iterations = _intField(kdf, 'iterations');
    if (iterations == null ||
        iterations < BackupCrypto.minIterations ||
        iterations > BackupCrypto.maxIterations) {
      throw const BackupFormatException(
        'Jumlah iterasi KDF backup tidak valid.',
      );
    }
    final salt = _decodeHexField(manifest, 'salt', BackupCrypto.saltBytes);
    final nonce = _decodeHexField(manifest, 'nonce', BackupCrypto.nonceBytes);
    if (blob.length < BackupCrypto.nonceBytes + 16) {
      throw const BackupFormatException('Payload backup tidak lengkap.');
    }
    final payloadNonce = blob.sublist(0, BackupCrypto.nonceBytes);
    for (var i = 0; i < nonce.length; i++) {
      if (payloadNonce[i] != nonce[i]) {
        throw const BackupFormatException(
          'Nonce manifest tidak cocok dengan payload.',
        );
      }
    }
    return (salt: salt, iterations: iterations);
  }

  Uint8List _decodeHexField(Map<String, dynamic> map, String name, int bytes) {
    final value = map[name];
    if (value is! String ||
        value.length != bytes * 2 ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      throw BackupFormatException('Field $name pada manifest tidak valid.');
    }
    return Uint8List.fromList(NkbBytes.unhex(value));
  }

  Future<void> _validateDatabaseFile(File file, String passphrase) async {
    AppDatabase? probe;
    try {
      probe = AppDatabase(
        openEncryptedExecutor(file: file, passphrase: passphrase),
      );
      final integrity = await probe
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      if (integrity.data.values.first?.toString() != 'ok') {
        throw BackupFormatException(
          'Integrity check gagal: ${integrity.data.values.first}',
        );
      }
      final rows = await probe
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final names = rows.map((row) => row.data['name'] as String).toSet();
      final missing = AppDatabase.requiredTableNames.difference(names);
      if (missing.isNotEmpty) {
        throw BackupFormatException(
          'Database hasil restore tidak lengkap: $missing',
        );
      }
    } finally {
      await probe?.close();
    }
  }

  Future<void> _deleteDatabaseFiles(String basePath) async {
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$basePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _cleanupSidecars(String basePath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$basePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  void _verifyChecksum(Uint8List blob, Map<String, dynamic> manifest) {
    final expected = manifest['checksum_sha256'];
    if (expected is! String || expected != NkbContainer.sha256Hex(blob)) {
      throw const BackupFormatException(
        'Checksum tidak cocok. File korup atau dimodifikasi.',
      );
    }
  }

  int? _intField(Map<Object?, Object?> map, String name) {
    final value = map[name];
    return value is int
        ? value
        : value is num && value == value.toInt()
        ? value.toInt()
        : null;
  }

  bool _isHexKey(String value) =>
      value.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);

  Map<String, int> _intMap(Object? raw) {
    if (raw is Map) {
      return raw.map((key, value) {
        final number = value is num ? value.toInt() : 0;
        return MapEntry(key.toString(), number);
      });
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
