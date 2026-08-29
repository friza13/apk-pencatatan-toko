import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Metadata for a backup stored in Google Drive.
class DriveBackupInfo {
  const DriveBackupInfo({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modifiedTime,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modifiedTime;
}

/// Abstract service for encrypted backup synchronization with Google Drive.
abstract class GoogleDriveBackupService {
  Future<bool> isSignedIn();
  Future<void> signIn();
  Future<void> signOut();
  Future<String> uploadEncryptedBackup(File nkbFile);
  Future<List<DriveBackupInfo>> listBackups();
  Future<File> downloadBackup(String fileId, String targetPath);
}

/// In-memory mock implementation of [GoogleDriveBackupService] for tests and offline/host runs.
class MockGoogleDriveBackupService implements GoogleDriveBackupService {
  bool _signedIn = false;
  final Map<String, _MockDriveFile> _storage = {};
  int _counter = 1;

  @override
  Future<bool> isSignedIn() async => _signedIn;

  @override
  Future<void> signIn() async {
    _signedIn = true;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
  }

  @override
  Future<String> uploadEncryptedBackup(File nkbFile) async {
    final fileId = 'gdrive_file_${_counter++}';
    final bytes = await nkbFile.readAsBytes();
    final name = nkbFile.uri.pathSegments.lastWhere(
      (s) => s.isNotEmpty,
      orElse: () => 'backup.nkb',
    );

    _storage[fileId] = _MockDriveFile(
      id: fileId,
      name: name,
      bytes: bytes,
      modifiedTime: DateTime.now().toUtc(),
    );

    return fileId;
  }

  @override
  Future<List<DriveBackupInfo>> listBackups() async {
    return _storage.values
        .map(
          (f) => DriveBackupInfo(
            id: f.id,
            name: f.name,
            sizeBytes: f.bytes.length,
            modifiedTime: f.modifiedTime,
          ),
        )
        .toList();
  }

  @override
  Future<File> downloadBackup(String fileId, String targetPath) async {
    final entry = _storage[fileId];
    if (entry == null) {
      throw Exception('File $fileId not found on Google Drive.');
    }
    final file = File(targetPath);
    await file.writeAsBytes(entry.bytes);
    return file;
  }
}

class _MockDriveFile {
  _MockDriveFile({
    required this.id,
    required this.name,
    required this.bytes,
    required this.modifiedTime,
  });

  final String id;
  final String name;
  final Uint8List bytes;
  final DateTime modifiedTime;
}

final googleDriveBackupServiceProvider =
    Provider<GoogleDriveBackupService>((ref) {
      return MockGoogleDriveBackupService();
    });
