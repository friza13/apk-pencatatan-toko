import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/security/auth_controller.dart';
import '../features/security/lock_screen.dart';

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
            'Terjadi kesalahan saat memuat data. '
            'Periksa penyimpanan lalu buka ulang aplikasi.',
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

class _Splash extends StatelessWidget {
  const _Splash({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                if (message == null) ...[
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
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
