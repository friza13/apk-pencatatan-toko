import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/security/auth_controller.dart';
import '../features/security/lock_screen.dart';
import '../features/security/providers.dart';

/// Gates the main app behind onboarding / lock based on [AuthPhase].
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.unlockedBuilder});

  /// Builds the authenticated application shell.
  final WidgetBuilder unlockedBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    return state.when(
      loading: () => const _Splash(),
      error: (e, _) => _Splash(
        message:
            'Terjadi kesalahan saat memuat data toko. '
            'Pastikan penyimpanan perangkat tersedia dan coba lagi.',
        errorDetails: e.toString(),
        onRetry: () {
          ref
            ..invalidate(appDatabaseProvider)
            ..invalidate(authControllerProvider);
        },
      ),
      data: (auth) {
        // Gated screens live outside the app's Navigator, so they carry
        // their own one-page Navigator (TextField overlays need it).
        Widget gate(Widget screen) => Navigator(
          onDidRemovePage: (page) {},
          pages: [MaterialPage<void>(key: ValueKey(auth.phase), child: screen)],
        );

        switch (auth.phase) {
          case AuthPhase.booting:
            return const _Splash();
          case AuthPhase.needsOnboarding:
            return gate(const OnboardingScreen());
          case AuthPhase.locked:
            return gate(const LockScreen());
          case AuthPhase.unlocked:
            return unlockedBuilder(context);
        }
      },
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash({
    this.message,
    this.errorDetails,
    this.onRetry,
  });

  final String? message;
  final String? errorDetails;
  final VoidCallback? onRetry;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_outlined,
                    size: 38,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NotaKit',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aplikasi Kasir & Pembukuan Toko',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 32),
                if (widget.message == null) ...[
                  SizedBox(
                    width: 140,
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Menyiapkan data toko...',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else ...[
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(180, 48),
                      ),
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                  if (widget.errorDetails != null &&
                      widget.errorDetails!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showDetails = !_showDetails);
                      },
                      icon: Icon(
                        _showDetails
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                      label: Text(
                        _showDetails
                            ? 'Sembunyikan Detail Kesalahan'
                            : 'Lihat Detail Kesalahan',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (_showDetails)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            widget.errorDetails!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
