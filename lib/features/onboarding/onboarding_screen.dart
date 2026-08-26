import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/auth_controller.dart';

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
  int _dataChoice = 0;
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

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).onboard(
            ownerName: _ownerName.text.trim(),
            businessName: _businessName.text.trim(),
            pin: _pin.text,
          );
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
                const ListTile(
                  enabled: false,
                  leading: Icon(null),
                  title: Text('Import backup'),
                  subtitle: Text('Pindahkan data dari HP lama (segera).'),
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
                maxLength: 8,
                decoration:
                    const InputDecoration(labelText: 'Ulangi PIN'),
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
