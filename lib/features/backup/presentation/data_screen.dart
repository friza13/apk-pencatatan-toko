import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../data/backup_service.dart';

final FutureProvider<BackupService> backupServiceProvider =
    FutureProvider<BackupService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return BackupService(db);
});

/// Backup & Restore (.nkb) - DESAIN §23 flow.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: passwordC,
            obscureText: true,
            autofocus: true,
            decoration:
                const InputDecoration(labelText: 'Password backup *'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Password tidak bisa dipulihkan oleh NotaKit. '
            'Simpan di tempat aman.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buat Backup')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final password = passwordC.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password minimal 6 karakter.')));
      return;
    }

    setState(() => _busy = true);
    try {
      final business = await ref.read(currentBusinessProvider.future);
      final repo = await ref.read(productRepositoryProvider.future);
      final counts = <String, int>{
        'products': (await repo.search(businessId: business.id)).length,
      };

      final service = await ref.read(backupServiceProvider.future);
      final docs = await getDocsDir();
      final file = await service.createBackup(
        sourceDbPath: '$docs/notakit.db',
        saveToPath: '$docs/notakit-${_stamp()}.nkb',
        password: password,
        schemaVersion: 1,
        appVersion: '1.0.0-dev',
        recordCounts: counts,
        dbKeyHex: await readDbKeyHex(),
        dbPassphrase: await readDbKeyHex(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Backup dibuat:\n${file.path}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    // file_picker v12: pickFiles langsung mengembalikan List<PlatformFile>.
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Pilih file .nkb',
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;

    final passwordC = TextEditingController();
    Map<String, int>? counts;
    String? createdAt;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulihkan Data'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Data saat ini akan DIGANTI dengan isi backup.'),
          const SizedBox(height: 12),
          TextField(
            controller: passwordC,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password backup'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjut')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Tutup koneksi aktif agar file bisa ditimpa aman.
      ref.invalidate(appDatabaseProvider);

      final service = await ref.read(backupServiceProvider.future);
      final preview = await service.inspect(
          nkbFile: File(path), password: passwordC.text);

      counts = preview.recordCounts;
      createdAt = preview.createdAtIso;

      final docs = await getDocsDir();
      await service.applyRestore(
        preview: preview,
        targetDbPath: '$docs/notakit.db',
        dbPassphrase: await readDbKeyHex(),
      );

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
              'Aplikasi memuat ulang data otomatis.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal restore: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup Sekarang'),
            subtitle: const Text('Buat file .nkb terenkripsi'),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _backupNow,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Pulihkan dari .nkb'),
            subtitle: const Text('Preview dulu sebelum menimpa data'),
            onTap: _busy ? null : _restore,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'File .nkb terenkripsi (AES-256-GCM + PBKDF2). Tanpa password, '
          'isi tidak bisa dibuka siapa pun termasuk NotaKit.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
    );
  }
}

// Helpers dipisah agar mudah di-mock pada widget test nanti.
Future<dynamic> getDocsDir() async => getApplicationDocumentsDirectory();

Future<String> readDbKeyHex() async {
  final store = FlutterSecureStoreAdapter(const FlutterSecureStorage());
  final key = await store.read('nk.db.key');
  if (key == null) {
    throw StateError('DB key belum ada.');
  }
  return key;
}
