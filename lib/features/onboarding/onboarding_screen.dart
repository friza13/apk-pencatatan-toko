import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../backup/controllers/backup_providers.dart';
import '../security/auth_controller.dart';
import '../security/auth_repository.dart';
import '../security/providers.dart';
import 'data/demo_data_seeder.dart';

/// 3-step onboarding (DESAIN §38):
///   1. "Kenalkan toko kamu" — nama owner + nama usaha
///   2. "Mulai dari data kamu" — data kosong (demo/backup menyusul)
///   3. "Siap jualan" — buat PIN
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _ownerName = TextEditingController();
  final _businessName = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();

  int _step = 0;
  int _dataChoice = 0; // 0=kosong, 1=demo
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ownerName.dispose();
    _businessName.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _ownerName.text.trim().isNotEmpty &&
            _businessName.text.trim().isNotEmpty;
      case 1:
        return true; // data kosong adalah pilihan default
      default:
        return _pin.text.length == 6 && _pin.text == _pinConfirm.text;
    }
  }

  /// Pulihkan .nkb saat onboarding: data owner/business ikut dari backup,
  /// lalu user diminta membuat PIN baru untuk perangkat ini (verifier PIN
  /// tidak ikut pindah karena tersimpan di secure storage perangkat lama).
  Future<String> getDocsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Pilih file .nkb');
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;

    final passwordC = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password backup'),
        content: TextField(
          controller: passwordC,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pulihkan')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(backupServiceProvider.future);
      final preview =
          await service.inspect(nkbFile: File(path), password: passwordC.text);

      // Tutup koneksi DB kosong bawaan onboarding sebelum file ditimpa.
      ref.invalidate(appDatabaseProvider);

      final docs = await getDocsDir();
      await service.applyRestore(
        preview: preview,
        targetDbPath: '$docs/notakit.db',
        dbPassphrase: preview.dbKeyHex,
      );

      // Kunci DB dari backup dipakai untuk membuka database terpulihkan.
      final secure = ref.read(secureStoreProvider);
      await secure.write('nk.db.key', preview.dbKeyHex);

      // PIN baru untuk perangkat ini.
      ref.invalidate(appDatabaseProvider);
      final repo = AuthRepository(
          db: await ref.read(appDatabaseProvider.future),
          secureStore: secure);
      if (!mounted) return;
      final pinC = TextEditingController();
      final pinSaved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Buat PIN baru'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Data berhasil dipulihkan. Buat PIN baru untuk perangkat ini.'),
            const SizedBox(height: 12),
            TextField(
              controller: pinC,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration:
                  const InputDecoration(labelText: 'PIN (6 digit)'),
            ),
          ]),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Simpan')),
          ],
        ),
      );
      if (pinSaved != true || !mounted) return;
      await repo.setPin(pinC.text);

      // Muat ulang auth state -> locked -> unlock dengan PIN baru.
      ref.invalidate(authControllerProvider);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final businessId = await ref.read(authControllerProvider.notifier).onboard(
          ownerName: _ownerName.text.trim(),
          businessName: _businessName.text.trim(),
          pin: _pin.text);
      if (_dataChoice == 1) {
        final db = await ref.read(appDatabaseProvider.future);
        await DemoDataSeeder(db).seed(businessId);
      }
    } on ArgumentError catch (e) {
      setState(() {
        _busy = false;
        _error = e.message?.toString() ?? 'Data belum lengkap.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Langkah ${_step + 1} dari 3',
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_step + 1) / 3),
              const SizedBox(height: 24),
              Expanded(child: _buildStep(theme)),
              if (_error != null) ...[
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed:
                    (_canContinue && !_busy) ? _onContinue : null,
                child: Text(_step < 2 ? 'Lanjut' : 'Mulai dengan NotaKit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onContinue() {
    if (_step < 2) {
      // Pilihan "Pulihkan dari backup" langsung menjalankan import
      // dan melewati step PIN (PIN baru diminta setelah restore).
      if (_step == 1 && _dataChoice == 2) {
        _importBackup();
        return;
      }
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  Widget _buildStep(ThemeData theme) {
    switch (_step) {
      case 0:
        return _StepCard(
          title: 'Kenalkan toko kamu',
          child: Column(
            children: [
              TextField(
                controller: _ownerName,
                decoration: const InputDecoration(labelText: 'Nama kamu'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _businessName,
                decoration:
                    const InputDecoration(labelText: 'Nama usaha'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        );
      case 1:
        return _StepCard(
          title: 'Mulai dari data kamu',
          child: RadioGroup<int>(
            groupValue: _dataChoice,
            onChanged: (v) => setState(() => _dataChoice = v ?? 0),
            child: Column(
              children: [
                RadioListTile<int>(
                  value: 0,
                  title: const Text('Mulai dengan data kosong'),
                  subtitle: const Text(
                      'Cocok untuk usaha yang baru mulai pakai NotaKit.'),
                ),
                RadioListTile<int>(
                  value: 1,
                  title: const Text('Pulihkan dari file backup'),
                  subtitle: const Text(
                      'Pindahkan data dari HP lama lewat file .nkb.'),
                ),
              ],
            ),
          ),
        );
      default:
        return _StepCard(
          title: 'Siap jualan — buat PIN',
          child: Column(
            children: [
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration:
                    const InputDecoration(labelText: 'PIN (6 digit)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinConfirm,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration:
                    const InputDecoration(labelText: 'Ulangi PIN (6 digit)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'PIN 6 digit dipakai untuk membuka aplikasi, seperti PIN '
                'bank. Data tersimpan terenkripsi di perangkat ini.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
    }
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
