import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'providers.dart';
export 'providers.dart' show pinHasherProvider;

/// High-level authentication lifecycle (FR-AUTH-001).
enum AuthPhase { booting, needsOnboarding, locked, unlocked }

class AuthState {
  const AuthState({
    required this.phase,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
  });

  final AuthPhase phase;

  /// Device has biometric hardware + enrolled credentials.
  final bool biometricAvailable;

  /// Owner opted in to biometric unlock.
  final bool biometricEnabled;

  bool get canUseBiometric => biometricAvailable && biometricEnabled;

  AuthState copyWith({AuthPhase? phase, bool? biometricAvailable, bool? biometricEnabled}) =>
      AuthState(
        phase: phase ?? this.phase,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      );
}

/// Result of an unlock attempt.
enum UnlockResult { success, wrongPin, notAvailable }

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final db = await ref.watch(appDatabaseProvider.future);
    final repo = AuthRepository(db: db, secureStore: ref.watch(secureStoreProvider));

    if (!await repo.isOnboarded()) {
      return const AuthState(phase: AuthPhase.needsOnboarding);
    }

    final bioEnabled = await repo.biometricEnabled();
    bool bioAvailable = false;
    try {
      bioAvailable =
          bioEnabled && await ref.read(biometricAuthProvider).isAvailable();
    } catch (_) {
      bioAvailable = false;
    }

    return AuthState(
      phase: AuthPhase.locked,
      biometricAvailable: bioAvailable,
      biometricEnabled: bioEnabled,
    );
  }

  Future<AuthRepository> _repo() async => AuthRepository(
        db: await ref.read(appDatabaseProvider.future),
        secureStore: ref.read(secureStoreProvider),
        hasher: ref.read(pinHasherProvider),
      );

  /// Creates the owner/business and unlocks immediately.
  Future<int> onboard({
    required String ownerName,
    required String businessName,
    required String pin,
  }) async {
    final repo = await _repo();
    final businessId = await repo.onboard(
        ownerName: ownerName, businessName: businessName, pin: pin);
    final current = state.value ??
        const AuthState(phase: AuthPhase.needsOnboarding);
    state = AsyncData(current.copyWith(
      phase: AuthPhase.unlocked,
      biometricEnabled: false,
    ));
    return businessId;
  }

  Future<UnlockResult> unlockWithPin(String pin) async {
    final ok = await (await _repo()).verifyPin(pin);
    if (!ok) {
      return UnlockResult.wrongPin;
    }
    state = AsyncData(
        (state.value ?? const AuthState(phase: AuthPhase.locked))
            .copyWith(phase: AuthPhase.unlocked));
    return UnlockResult.success;
  }

  Future<UnlockResult> unlockWithBiometric() async {
    final current = state.value;
    if (current == null || !current.canUseBiometric) {
      return UnlockResult.notAvailable;
    }
    final ok = await ref
        .read(biometricAuthProvider)
        .authenticate(reason: 'Buka NotaKit untuk melanjutkan');
    if (!ok) {
      return UnlockResult.wrongPin;
    }
    state = AsyncData(current.copyWith(phase: AuthPhase.unlocked));
    return UnlockResult.success;
  }

  void lock() {
    final current = state.value;
    if (current == null || current.phase != AuthPhase.unlocked) {
      return;
    }
    state = AsyncData(current.copyWith(phase: AuthPhase.locked));
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
