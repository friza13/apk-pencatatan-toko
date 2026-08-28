import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// PIN lock screen (DESAIN §45: security UX; §12: numeric keypad).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  void _onDigit(String digit) {
    if (_busy || _pin.length >= 6) {
      return;
    }
    setState(() {
      _error = null;
      _pin += digit;
    });
    // PIN is always exactly 6 digits (D-023) — submit when complete.
    if (_pin.length == 6) {
      _tryUnlock();
    }
  }

  Future<void> _tryUnlock() async {
    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .unlockWithPin(_pin);
    if (!mounted) {
      return;
    }
    if (result == UnlockResult.success) {
      return;
    }
    setState(() {
      _busy = false;
      _pin = '';
      _error = 'PIN salah. Coba lagi.';
    });
  }

  Future<void> _onBiometric() async {
    await ref.read(authControllerProvider.notifier).unlockWithBiometric();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider).value;
    final canBiometric = state?.canUseBiometric ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text('NotaKit', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Masukkan PIN untuk membuka',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const Spacer(),
            _PinPad(
              onDigit: _onDigit,
              onDelete: () {
                if (_pin.isNotEmpty && !_busy) {
                  setState(() => _pin = _pin.substring(0, _pin.length - 1));
                }
              },
            ),
            if (canBiometric)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: IconButton.outlined(
                  onPressed: _busy ? null : _onBiometric,
                  icon: const Icon(Icons.fingerprint, size: 32),
                  tooltip: 'Buka dengan biometrik',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onDelete});

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          for (final row in keys)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        height: 64,
                        child: k.isEmpty
                            ? const SizedBox.shrink()
                            : k == 'del'
                            ? IconButton(
                                onPressed: onDelete,
                                icon: const Icon(Icons.backspace_outlined),
                              )
                            : FilledButton.tonal(
                                onPressed: () => onDigit(k),
                                child: Text(
                                  k,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
