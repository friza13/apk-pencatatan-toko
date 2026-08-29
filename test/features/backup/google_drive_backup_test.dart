import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/features/backup/data/google_drive_backup_service.dart';

void main() {
  group('GoogleDriveBackupService & Mock', () {
    late MockGoogleDriveBackupService service;
    late Directory tempDir;

    setUp(() async {
      service = MockGoogleDriveBackupService();
      tempDir = await Directory.systemTemp.createTemp('gdrive_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('signs in, uploads encrypted .nkb file, lists backups, and downloads', () async {
      expect(await service.isSignedIn(), isFalse);

      await service.signIn();
      expect(await service.isSignedIn(), isTrue);

      final dummyFile = File('${tempDir.path}/backup_2026_08_29.nkb');
      await dummyFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

      final fileId = await service.uploadEncryptedBackup(dummyFile);
      expect(fileId, isNotEmpty);

      final backups = await service.listBackups();
      expect(backups, hasLength(1));
      expect(backups.first.id, equals(fileId));
      expect(backups.first.name, equals('backup_2026_08_29.nkb'));
      expect(backups.first.sizeBytes, equals(8));

      final downloadedFile = File('${tempDir.path}/downloaded.nkb');
      await service.downloadBackup(fileId, downloadedFile.path);

      expect(await downloadedFile.exists(), isTrue);
      expect(await downloadedFile.readAsBytes(), equals([1, 2, 3, 4, 5, 6, 7, 8]));

      await service.signOut();
      expect(await service.isSignedIn(), isFalse);
    });
  });
}
