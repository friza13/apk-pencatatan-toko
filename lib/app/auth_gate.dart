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
      error: (e, _) => _Splash(message: 'Terjadi kesalahan saat memuat data. '
          'Periksa penyimpanan lalu buka ulang aplikasi.'),
      data: (auth) {
        // Gated screens live outside the app's Navigator, so they carry
        // their own one-page Navigator (TextField overlays need it).
        Widget gate(Widget screen) => Navigator(
              onDidRemovePage: (page) {},
              pages: [
                MaterialPage<void>(
                  key: ValueKey(auth.phase),
                  child: screen,
                ),
              ],
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
    return Scaffold(
      body: Center(
        child: message == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message!),
              ),
      ),
    );
  }
}
