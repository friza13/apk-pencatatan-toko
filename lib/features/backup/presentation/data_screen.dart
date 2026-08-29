import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app/app_metadata.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../controllers/backup_providers.dart';
import '../data/google_drive_backup_service.dart';

/// Backup & Restore (.nkb) - DESAIN §23 flow.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  String? _busyAction;

  String _stamp() {
    final d = DateTime.now().toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}';
  }

  Future<void> _backupNow() async {
    final passwordC = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Sekarang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordC,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password backup *'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Password tidak bisa dipulihkan oleh NotaKit. '
              'Simpan di tempat aman.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buat Backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = passwordC.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 6 karakter.')),
      );
      return;
    }

    setState(() => _busyAction = 'local_backup');
    try {
      final business = await ref.read(currentBusinessProvider.future);
      final repo = await ref.read(productRepositoryProvider.future);
      final counts = <String, int>{
        'products': (await repo.search(businessId: business.id)).length,
      };

      final service = await ref.read(backupServiceProvider.future);
      final docs = await getDocsDir();
      final db = await ref.read(appDatabaseProvider.future);
      final metadata = await AppMetadata.load(db);
      final file = await service.createBackup(
        sourceDbPath: '${docs.path}\\notakit.db',
        saveToPath: '${docs.path}\\notakit-${_stamp()}.nkb',
        password: password,
        schemaVersion: metadata.schemaVersion,
        appVersion: metadata.appVersion,
        recordCounts: counts,
        dbKeyHex: await readDbKeyHex(),
        dbPassphrase: await readDbKeyHex(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup dibuat:\n${file.path}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _restore() async {
    // file_picker v12: pickFiles langsung mengembalikan List<PlatformFile>.
    final picked = await FilePicker.pickFiles(dialogTitle: 'Pilih file .nkb');
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;

    final passwordC = TextEditingController();
    Map<String, int>? counts;
    String? createdAt;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulihkan Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Data saat ini akan DIGANTI dengan isi backup.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password backup'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyAction = 'local_restore');
    try {
      final service = await ref.read(backupServiceProvider.future);
      final preview = await service.inspect(
        nkbFile: File(path),
        password: passwordC.text,
      );

      counts = preview.recordCounts;
      createdAt = preview.createdAtIso;
      if (!mounted) return;
      final apply = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Konfirmasi restore'),
          content: Text(
            'Backup dibuat: ${createdAt ?? '-'}\n'
            'Produk: ${counts?['products'] ?? '-'}\n'
            'Pelanggan: ${counts?['customers'] ?? '-'}\n'
            'Nota: ${counts?['sales'] ?? '-'}\n\n'
            'Data saat ini akan diganti secara permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ganti Data'),
            ),
          ],
        ),
      );
      if (apply != true || !mounted) return;

      setState(() => _busyAction = 'local_restore');

      // Tutup koneksi aktif hanya after preview confirmation.
      await closeAppDatabaseForRestore(
        readDatabase: () => ref.read(appDatabaseProvider.future),
        invalidateDatabase: () => ref.invalidate(appDatabaseProvider),
      );

      final docs = await getDocsDir();
      await service.applyRestore(
        preview: preview,
        targetDbPath: '${docs.path}\\notakit.db',
        dbPassphrase: preview.dbKeyHex,
      );

      final secure = ref.read(secureStoreProvider);
      await secure.write('nk.db.key', preview.dbKeyHex);

      // Buka ulang koneksi & muat ulang seluruh data.
      ref.invalidate(appDatabaseProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restore selesai'),
          content: Text(
            'Dibuat: ${createdAt ?? '-'}\n'
            'Produk: ${counts?['products'] ?? '-'}\n'
            'Pelanggan: ${counts?['customers'] ?? '-'}\n'
            'Nota: ${counts?['sales'] ?? '-'}\n\n'
            'Aplikasi memuat ulang data otomatis.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal restore: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _backupToGoogleDrive() async {
    final passwordC = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadangkan ke Google Drive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordC,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password enkripsi *'),
            ),
            const SizedBox(height: 8),
            const Text(
              'File .nkb dienkripsi sebelum diunggah ke Google Drive.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unggah Backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = passwordC.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 6 karakter.')),
      );
      return;
    }

    setState(() => _busyAction = 'gdrive_backup');
    try {
      final business = await ref.read(currentBusinessProvider.future);
      final repo = await ref.read(productRepositoryProvider.future);
      final counts = <String, int>{
        'products': (await repo.search(businessId: business.id)).length,
      };

      final service = await ref.read(backupServiceProvider.future);
      final docs = await getDocsDir();
      final db = await ref.read(appDatabaseProvider.future);
      final metadata = await AppMetadata.load(db);
      final file = await service.createBackup(
        sourceDbPath: '${docs.path}\\notakit.db',
        saveToPath: '${docs.path}\\notakit-gdrive-${_stamp()}.nkb',
        password: password,
        schemaVersion: metadata.schemaVersion,
        appVersion: metadata.appVersion,
        recordCounts: counts,
        dbKeyHex: await readDbKeyHex(),
        dbPassphrase: await readDbKeyHex(),
      );

      final gdrive = ref.read(googleDriveBackupServiceProvider);
      await gdrive.uploadEncryptedBackup(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup terenkripsi berhasil diunggah ke Google Drive!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal backup ke Google Drive: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _restoreFromGoogleDrive() async {
    setState(() => _busyAction = 'gdrive_restore');
    List<DriveBackupInfo> backups = [];
    try {
      final gdrive = ref.read(googleDriveBackupServiceProvider);
      backups = await gdrive.listBackups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat backup Google Drive: $e')),
        );
      }
      setState(() => _busyAction = null);
      return;
    } finally {
      setState(() => _busyAction = null);
    }

    if (!mounted) return;
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada backup di Google Drive.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<DriveBackupInfo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Backup dari Google Drive',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final b in backups)
                      ListTile(
                        leading: const Icon(Icons.cloud_done_outlined),
                        title: Text(b.name),
                        subtitle: Text(
                          'Ukuran: ${b.sizeBytes} bytes • ${b.modifiedTime.toLocal()}',
                        ),
                        onTap: () => Navigator.pop(ctx, b),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _busyAction = 'gdrive_restore');
    try {
      final gdrive = ref.read(googleDriveBackupServiceProvider);
      final tempDir = await Directory.systemTemp.createTemp('gdrive_restore_');
      final targetFile = File('${tempDir.path}/${selected.name}');
      await gdrive.downloadBackup(selected.id, targetFile.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup ${selected.name} diunduh. Silakan pulihkan.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup Sekarang'),
              subtitle: const Text('Buat file .nkb terenkripsi lokal'),
              trailing: _busyAction == 'local_backup'
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _busyAction != null ? null : _backupNow,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Pulihkan dari .nkb'),
              subtitle: const Text('Preview dulu sebelum menimpa data'),
              trailing: _busyAction == 'local_restore'
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _busyAction != null ? null : _restore,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Cadangkan ke Google Drive'),
              subtitle: const Text('Simpan file .nkb terenkripsi ke Cloud'),
              trailing: _busyAction == 'gdrive_backup'
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _busyAction != null ? null : _backupToGoogleDrive,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Pulihkan dari Google Drive'),
              subtitle: const Text('Unduh dan pulihkan data dari Google Drive'),
              trailing: _busyAction == 'gdrive_restore'
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _busyAction != null ? null : _restoreFromGoogleDrive,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'File .nkb terenkripsi (AES-256-GCM + PBKDF2). Tanpa password, '
            'isi tidak bisa dibuka siapa pun termasuk NotaKit atau Google.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// Helpers dipisah agar mudah di-mock pada widget test nanti.
Future<Directory> getDocsDir() => getApplicationDocumentsDirectory();

Future<String> readDbKeyHex() async {
  final store = FlutterSecureStoreAdapter(const FlutterSecureStorage());
  final key = await store.read('nk.db.key');
  if (key == null) {
    throw StateError('DB key belum ada.');
  }
  return key;
}
