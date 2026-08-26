# P3 Auth & Store — Implementation Plan

**Goal:** Owner onboarding (≤3 langkah), PIN app-lock + biometrik opsional, profil toko dasar, settings minimum — dengan Riverpod controllers teruji.

**Spec:** FR-AUTH-001/FR-STORE-001, SRS NFR-003, DESAIN §38/§44/§45, D-003 (key model).

## Model keamanan (D-022)

- Kunci DB = **random 256-bit**, dibuat sekali, disimpan di secure storage (Keystore-wrapped). TIDAK diturunkan dari PIN (rotasi PIN tidak merusak DB).
- PIN disimpan sebagai **salted PBKDF2-HMAC-SHA256 hash** di secure storage (defense-in-depth; bukan mekanisme utama). Iterasi 100k demi unlock <300ms — dokumentasi risiko: kekuatan utama dari Keystore + enkripsi DB.
- Password backup `.nkb` independen, user-supplied per backup (P10).
- Biometrik hanya gate kenyamanan; fallback PIN selalu ada.

## Tasks

### P3-1 Deps + kontrak
- `flutter pub add flutter_secure_storage local_auth`
- Interface `SecureStore` (+ InMemory fake), `BiometricAuthenticator`.
- MainActivity → FlutterFragmentActivity (syarat local_auth).
- Commit: `feat(auth): contracts and platform prerequisites`

### P3-2 PinHasher + tests
- `lib/core/security/pin_hasher.dart`: hash(pin,salt) PBKDF2 100k; constant-time compare.
- Commit: `feat(security): pin hashing`

### P3-3 AuthRepository + bootstrap service
- `lib/features/security/auth_repository.dart`: ensureDbKey() (buat/random jika absen),
  isOnboarded, onboard(owner,business,pin), verifyPin, biometric flag get/set,
  ganti PIN. Semua lewat AppDatabase (owners/businesses/app_settings).
- Test host dengan NativeDatabase.memory() + fake secure store: happy path, PIN salah,
  re-onboard ditolak.
- Commit: `feat(auth): repository`

### P3-4 AuthController (Riverpod) + tests
- State machine: `booting → needsOnboarding | locked(biometricEnabled) | unlocked`.
- Aksi: onboard(...), unlockWithPin, unlockWithBiometric, lock, logout tidak ada (single-owner).
- Commit: `feat(auth): riverpod controller`

### P3-5 UI Lock + Onboarding + router guard
- LockScreen: greeting, PIN pad besar, tombol biometrik bila aktif, error inline.
- OnboardingScreen 3 langkah (DESAIN §38): Kenalkan toko → mulai data kosong/demo → siap jualan (PIN setup).
- Router redirect berdasarkan auth state; Beranda menampilkan nama toko.
- Widget test: alur onboarding selesai → masuk Beranda; PIN salah → pesan.
- Commit: `feat(ui): lock and onboarding flows`

### P3-6 Settings minimum + CHECKPOINT
- Layar Lainnya → Toko Saya (edit nama/alamat/footer/prefix), Keamanan (ganti PIN, toggle biometrik).
- Gates penuh + lapor owner sebelum P4.
