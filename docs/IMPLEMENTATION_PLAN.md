# NotaKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, dengan checkpoint owner) untuk mengeksekusi plan ini task-by-task. Steps memakai checkbox (`- [ ]`) untuk tracking. Checkpoint wajib: berhenti & laporkan sesuai §Execution Checkpoints.

**Goal:** Membangun NotaKit MVP — POS/nota UMKM local-first single-owner di Android dengan DB terenkripsi sejak v1 dan backup `.nkb`.

**Architecture:** Clean Architecture feature-first: UI → Riverpod controller → UseCase → Domain rules → Repository → Drift(SQLite/SQLCipher). Adapter interfaces untuk printer/marketplace/notification/secure-storage.

**Tech Stack:** Flutter 3.44.0/Dart 3.12.0 • Riverpod • go_router • Drift + SQLite + SQLCipher-compatible • AES-256-GCM + PBKDF2-HMAC-SHA256 • freezed/json_serializable • flutter_secure_storage • local_auth • pdf/printing • share_plus.

**Spec:** `docs/NOTAKIT_PRD.md`, `docs/NOTAKIT_SRS.md`, `docs/NOTAKIT_ERD.md`, `docs/NOTAKIT_SYSTEM_ARCHITECTURE.md`, `docs/DESAIN.md` + amendment owner (lihat `docs/AI_DECISION_LOG.md`).

## Global Constraints

- Nama produk **NotaKit** di semua UI/package/doc; jangan e-Nota/ENOTA/Clone.
- Local-first, offline-first, single-owner, no subscription/SaaS/multi-tenant/server wajib.
- Money = integer minor unit (`Rp10.500 → 10500`); dilarang float untuk uang; rounding via satu `MoneyPolicy`.
- Quantity = integer micro-unit; konstanta tunggal `quantityScale = 1000000` di core domain.
- Timestamp disimpan UTC; render via business timezone utility terpusat.
- Inventory movement ledger = source of truth; cached stock hanya derived.
- Transaksi final immutable; ubah via VOID/RETURN; DRAFT tidak mengurangi stok.
- WAC update atomic saat purchase finalize (bukan draft).
- OVERDUE derived: `due_date < business_now AND outstanding > 0`.
- DB terenkripsi sejak schema v1 (gate: spike lulus); tidak ada downgrade silent ke plaintext.
- Backup `.nkb`: AES-256-GCM + PBKDF2 (parameter via manifest, algorithm-agile); manifest minimal fields per D-002; restore: validate→decrypt→verify→schema-check→preview→temp-db→integrity→atomic swap→audit.
- CSV UTF-8 RFC4180 untuk export MVP; XLSX post-MVP.
- Fitur Phase 2/3 disembunyikan dari UI MVP.
- Setiap checkpoint: `flutter analyze`, `flutter test`, `flutter build apk --debug` (jika relevan), commit lokal (tanpa push).
- UI mengikuti `DESAIN.md` (Indigo #2563EB, Inter, spacing 4pt, bottom nav 5 tab, komponen NK*).

## Roadmap Fase

| Fase | Isi | Status |
|---|---|---|
| P0 | Foundation: git, flutter create, lint, theme NK, router, Result/Error | ✅ selesai |
| SPIKE | SQLCipher+Drift POC 8 area (GATE sebelum schema produksi) | ✅ lulus |
| P1 | Database schema v1 penuh (ERD + amendments) + migration harness + DAO tests | ✅ selesai; migration lanjutan P1 |
| P2 | Core domain: MoneyPolicy, Quantity, pricing engine, discount engine, datetime util (pure Dart, full test) | ✅ selesai |
| P3 | Auth & store: onboarding owner, business profile, PIN+biometric, secure storage, settings | ✅ selesai; settings lanjutan P1 |
| P4 | Master data: category/unit/product(variant/unit konversi)/customer(type)/supplier/salesman + CRUD UI | ✅ selesai |
| P5 | Inventory: movement service, opening balance, adjustment/opname, kartu stok, low-stock | ✅ selesai |
| P6 | Sales: cart → checkout atomic, daftar nota, detail, void/return, refund doc | ⚠ checkout/credit hardened; return/refund dan void reversal deferred |
| P7 | Receivable & cash: payment allocation, piutang UI, kas/bank/expense/transfer, arus kas | ✅ selesai; P0 consistency follow-up |
| P8 | Reports: dashboard KPI, penjualan, laba (COGS snapshot), nilai stok, CSV export | ✅ selesai; precision follow-up |
| P9 | Printing/PDF: receipt renderer 58/80/A4, share, printer profile (+transport adapter) | ✅ renderer/PDF/share; transport deferred |
| P10 | Backup: `.nkb` container, validate/preview/temp-db/atomic-swap restore, audit | ✅ recovery path verified on Android emulator; crash injection still pending |
| P11 | Hardening MVP: integration/recovery tests, demo data, perf pass → **MVP DONE** | ✅ analyzer, full tests, debug APK, and Android recovery integration verified; release hardening follow-ups remain |
| P12–P13 | Phase 2/3 (restaurant/minimarket/purchase lanjutan/marketplace adapter) | deferred |

Setiap fase P1+ akan dipecah menjadi detailed task plan (gaya bite-sized/TDD) yang ditulis **just-in-time** sebelum eksekusi fase tersebut ke `docs/superpowers/plans/YYYY-MM-DD-<fase>.md`. Di bawah ini detail penuh untuk P0 + SPIKE.

---

## Task 0: Git init + .gitignore

**Files:**
- Create: `.gitignore`

- [x] **Step 1:** `git init`
- [x] **Step 2:** Buat `.gitignore` standar Flutter + pengecualian docs:

```gitignore
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.build/
.buildlog/
.history
.svn/
.swiftpm/
migrate_working_dir/

# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

# VS Code
.vscode/

# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/
/build/

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

# Android Studio build artifacts
/android/app/debug
/android/app/profile
/android/app/release

# NotaKit local secrets (never commit)
*.keystore
*.jks
key.properties
```

- [ ] **Step 3:** Commit: `chore: initialize repository with discovery documents`

## Task 1: Flutter project foundation

**Files:**
- Generate: `pubspec.yaml`, `lib/main.dart`, `android/`, `test/` (via template)

- [ ] **Step 1:** Jalankan di root repo (menambahkan file Flutter tanpa menghapus docs):

```bash
flutter create --org com.notakit --project-name notakit .
```

Hasil: package `notakit`, applicationId `com.notakit.notakit` (resolusi U-05).

- [ ] **Step 2:** Verifikasi: `flutter analyze` tanpa error; `flutter test` template test lolos.

## Task 2: Verifikasi Android toolchain (Step 4 owner)

- [ ] **Step 1:** `flutter doctor -v` → catat hasil; Android toolchain harus ✓ (atau laporkan blocker).
- [ ] **Step 2:** `flutter devices` + `flutter emulators` → catat device/emulator yang tersedia untuk spike nanti.
- [ ] Jika Android SDK bermasalah → STOP, laporkan sebelum lanjut (dilarang modifikasi global env tanpa approval).

## Task 3: Lint ketat + struktur folder

**Files:**
- Modify: `analysis_options.yaml`
- Create: folder `lib/app`, `lib/core/*`, `lib/features/*`, `lib/database`, `lib/shared/*` (dengan `.gitkeep` atau file pertama masing-masing)

- [ ] **Step 1:** `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    always_declare_return_types: true
    avoid_print: true
    avoid_dynamic_calls: true
    prefer_final_locals: true
    prefer_single_quotes: true
    unawaited_futures: true
    unnecessary_await_in_return: true
    cascade_invocations: true
```

- [ ] **Step 2:** `dart pub get && flutter analyze` → PASS.

## Task 4: Core Result/Error types (TDD)

**Files:**
- Create: `lib/core/result/result.dart`
- Create: `lib/core/error/failures.dart`
- Test: `test/core/result/result_test.dart`

**Interfaces (produces):**
```dart
sealed class Result<T> { ... }           // Success<T>(data) | Failure<T>(Failure)
class Failure { final String code; final String message; final Object? cause; }
abstract class ErrorCodes { static const stockInsufficient = 'STOCK_INSUFFICIENT'; /* dst SRS */ }
```

- [ ] **Step 1:** Tulis failing test `result_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/error/failures.dart';
import 'package:notakit/core/result/result.dart';

void main() {
  group('Result', () {
    test('success holds value', () {
      final r = Result<int>.success(7);
      expect(r.isSuccess, isTrue);
      expect(r.dataOrNull, 7);
    });
    test('failure holds code and message', () {
      const f = Failure(code: ErrorCodes.invalidPin, message: 'PIN salah');
      final r = Result<int>.failure(f);
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull?.code, 'INVALID_PIN');
    });
    test('when maps both branches', () {
      String f(Result<int> r) =>
          r.when(success: (v) => 'ok $v', failure: (e) => 'err ${e.code}');
      expect(f(Result<int>.success(1)), 'ok 1');
      expect(
        f(const Result<int>.failure(Failure(code: 'X', message: ''))),
        'err X',
      );
    });
  });
}
```

- [ ] **Step 2:** Run `flutter test` → FAIL (file belum ada).
- [ ] **Step 3:** Implementasi minimal:

```dart
// lib/core/result/result.dart
import '../error/failures.dart';

sealed class Result<T> {
  const Result();
  bool get isSuccess => this is Success<T>;
  T? get dataOrNull => switch (this) { Success<T>(:final data) => data, _ => null };
  Failure? get failureOrNull => switch (this) { FailureResult<T>(:final failure) => failure, _ => null };
  R when<R>({required R Function(T data) success, required R Function(Failure f) failure}) =>
      switch (this) { Success<T>(:final data) => success(data), FailureResult<T>(:final failure) => failure(failure) };
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}
extension ResultFailure<T> on Result<T> {
  // helper alias agar pola `Result.failure(f)` bisa dipakai sebagai constructor named
}
```

Catatan implementasi: gunakan constructor factory `Result.success/.failure` yang memetakan ke `Success`/`FailureResult` (nama kelas failure dibedakan dari value object `Failure`).

```dart
// lib/core/error/failures.dart
class Failure {
  const Failure({required this.code, required this.message, this.cause});
  final String code;
  final String message;
  final Object? cause;
  @override
  String toString() => 'Failure($code, $message)';
}

abstract class ErrorCodes {
  static const authLocked = 'AUTH_LOCKED';
  static const invalidPin = 'INVALID_PIN';
  static const productNotFound = 'PRODUCT_NOT_FOUND';
  static const productInactive = 'PRODUCT_INACTIVE';
  static const stockInsufficient = 'STOCK_INSUFFICIENT';
  static const invalidQuantity = 'INVALID_QUANTITY';
  static const invalidDiscount = 'INVALID_DISCOUNT';
  static const invalidPayment = 'INVALID_PAYMENT';
  static const receivableLimitExceeded = 'RECEIVABLE_LIMIT_EXCEEDED';
  static const duplicateTransaction = 'DUPLICATE_TRANSACTION';
  static const backupInvalid = 'BACKUP_INVALID';
  static const backupWrongPassword = 'BACKUP_WRONG_PASSWORD';
  static const backupSchemaUnsupported = 'BACKUP_SCHEMA_UNSUPPORTED';
  static const backupCorrupted = 'BACKUP_CORRUPTED';
  static const marketplaceUnauthorized = 'MARKETPLACE_UNAUTHORIZED';
  static const marketplaceRateLimited = 'MARKETPLACE_RATE_LIMITED';
  static const marketplaceDuplicateOrder = 'MARKETPLACE_DUPLICATE_ORDER';
  static const printerNotFound = 'PRINTER_NOT_FOUND';
  static const printerConnectionFailed = 'PRINTER_CONNECTION_FAILED';
  static const databaseError = 'DATABASE_ERROR';
}
```

- [ ] **Step 4:** `flutter test` → PASS; commit `feat: add core result and error types`.

## Task 5: Theme NotaKit (DESAIN.md)

**Files:**
- Create: `lib/app/theme/app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_theme.dart`
- Test: `test/app/theme/theme_golden_smoke_test.dart` (smoke: light/dark ThemeData valid, warna primary benar)

- [ ] **Step 1:** Tulis smoke test (failing): pastikan `AppTheme.light().colorScheme.primary == Color(0xFF2563EB)` dan dark background `#0B1220`.
- [ ] **Step 2:** Implementasi tokens sesuai DESAIN.md (palet lengkap §3–§4, scale tipografi Inter §5 — `fontFamily: 'Inter'` string; bundling font file dilakukan saat tersedia asset, fallback otomatis ke sistem), spacing/radius constants §6–§7, `MaterialTheme` light+dark.
- [ ] **Step 3:** Test PASS; commit `feat: add NotaKit design tokens and theme`.

## Task 6: Router + shell aplikasi

**Files:**
- Create: `lib/app/router/app_router.dart`, `lib/features/dashboard/dashboard_screen.dart` (placeholder Beranda)
- Modify: `lib/main.dart` (bootstrap: `MaterialApp.router`, theme light/dark)

- [ ] **Step 1:** Widget test: pump app → tampilkan 'Beranda'; route `/home` resolve. 
- [ ] **Step 2:** Implementasi `go_router` minimal (route `/home`); bottom-nav 5 tab adalah scaffold kosong bertuliskan nama tab (Beranda/Penjualan/Produk/Laporan/Lainnya) — konten nyata menyusul per fase.
- [ ] **Step 3:** PASS; commit `feat: add app shell with navigation skeleton`.

## CHECKPOINT P0 (wajib)

- [ ] `flutter analyze` → 0 issue
- [ ] `flutter test` → all pass
- [ ] `flutter build apk --debug` → BUILD SUCCESSFUL
- [ ] Commit: `chore: initialize NotaKit project` (squash logis per task sudah terpisah)
- [ ] **STOP → lapor hasil P0 ke owner sebelum SPIKE.**

---

## Task S0–Sn: SPIKE SQLCipher + Drift (GATE — sebelum schema produksi)

**Tujuan:** Buktikan 8 area: (1) open encrypted DB, (2) Drift CRUD, (3) FK, (4) transaction, (5) migration, (6) restart persistence, (7) Android build compatibility, (8) interaksi backup/restore (copy file byte-level). Plus benchmark PBKDF2.

**Pendekatan dua jalur:**
- **Jalur host (Windows, cepat):** logika drift+migration+transaction diuji dengan `NativeDatabase` sqlite3 biasa (tanpa cipher — cipher adalah layer native Android). Benchmark PBKDF2 (pure Dart) dijalankan di sini.
- **Jalur Android (penentu):** integration test (`integration_test/`) dijalankan di emulator/device sungguhan memakai `sqlcipher_flutter_libs` + `PRAGMA key`. **Inilah bukti enkripsi.** Jika tidak ada emulator tersedia → minta owner menyiapkan device/emulator; spike Android tidak boleh dilewati.

**Files:**
- Create: `pubspec.yaml` deps: `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `sqlcipher_flutter_libs`, dev: `drift_dev`, `build_runner`, `integration_test`
- Create: `spike/spike_database.dart` (Drift database spike 2 tabel + migration v1→v2)
- Create: `integration_test/spike_encrypted_db_test.dart`
- Create: `test/spike/kdf_benchmark_test.dart`
- Create: `docs/SPIKE_REPORT.md` (output)

**Interfaces:**
```dart
@DriftDatabase(tables: [SpikeCategories, SpikeProducts])
class SpikeDatabase { ... }   // v2: tambah kolom note pada products
QueryExecutor openSpikeExecutor({required String path, required String passphrase});
```
Open pattern (Android):
```dart
// drift_flutter: driftDatabase(name: ..., setup: (db) {
//   assert(db.select('PRAGMA key') ...); // sebenarnya:
//   db.execute("PRAGMA key = '$passphrase'");
//   db.execute('PRAGMA foreign_keys = ON');
// })
```
(Exact API diverifikasi saat eksekusi terhadap versi package terkini; prinsip: PRAGMA key dieksekusi pada open, foreign_keys ON, WAL ON.)

- [ ] **S-1:** Tambah dependencies; `flutter pub get`.
- [ ] **S-2:** Host test: buat spike DB in-memory/file sementara → CRUD → FK violation terlempar → transaction rollback saat error → migration v1→v2 mempertahankan data.
- [ ] **S-3:** Benchmark PBKDF2 (mis. paket `cryptography` atau `pointycastle`) iterasi kandidat 100k/200k/400k/600k/800k → catat ms di `SPIKE_REPORT.md`; pilih nilai ≤ ~500ms budget unlock.
- [ ] **S-4:** Integration test Android: open encrypted (passphrase benar → OK; salah → gagal verifikasi), CRUD, FK, transaction, restart persistence (tutup & buka ulang), backup = copy file → hapus → restore copy → data utuh.
- [ ] **S-5:** `flutter build apk --debug` sukses dengan sqlcipher libs (bukti build compatibility).
- [ ] **S-6:** Tulis `docs/SPIKE_REPORT.md`: hasil per area, versi package, benchmark KDF, keputusan iterasi final (update D-004), blocker jika ada.
- [ ] **CHECKPOINT SPIKE:** lapor hasil ke owner. **LULUS → lanjut P1. BLOCKER SERIUS → STOP, jangan fallback silent.**

---

## Execution Checkpoints (aturan owner)

```
P0 Foundation → CHECKPOINT (lapor)
SPIKE SQLCipher → CHECKPOINT (lapor; GATE)
P1 Database → CHECKPOINT
P2 Domain → CHECKPOINT
P3+ → per fase, sama
```

Setiap checkpoint: `flutter analyze` ✓, `flutter test` ✓, `flutter build apk --debug` ✓ (bila relevan), commit lokal milestone, tidak ada perubahan sisa yang tidak disengaja. Push dilarang tanpa permintaan eksplisit owner.

## Self-Review Notes

- Spec coverage: semua amendment #1–#20 terpetakan (D-001..D-018, G-01..G-12, C-01..C-06); fase P1–P13 akan mendapat detailed plan just-in-time sehingga coverage per-task diverifikasi saat itu (mencegah plan basi).
- Placeholder scan: kode di atas adalah kerangka nyata; API drift/sqlcipher exact diverifikasi terhadap versi package saat eksekusi (dicatat eksplisit di S-1/S-6, bukan tebak-tebakan diam-diam).
- Type consistency: `Result/Failure/ErrorCodes` dipakai konsisten mulai P2+; naming `_micro` untuk qty, integer minor untuk money.

## Execution Log

| Tanggal | Milestone | Hasil | Commit |
|---|---|---|---|
| 2026-08-26 | Task 0–2 (git init, docs, flutter create) | ✓ | `4a3dae8` |
| 2026-08-26 | P0 Foundation + CHECKPOINT | analyze 0 issue • test 11/11 • apk debug ✓ | `34f4b8f` |
| 2026-08-26 | SPIKE SQLCipher+Drift — **PASS** | 9/9 integration test @ emulator • KDF benchmark selesai → lihat `docs/SPIKE_REPORT.md`, keputusan D-019/D-020 | `38f05e9` |
| 2026-08-26 | P1 Database — **PASS** | Schema v1 (36 tabel) • DAO/constraint tests di host • analyze 0 • test 35+ pass • apk ✓ → delta terdokumentasi D-021 | `0df080a` |
| 2026-08-26 | P2 Core domain — **PASS** | Qty, MoneyPolicy (D-011 penuh), PricingEngine (FR-PRICE-001), BusinessClock (D-012) • 41 domain tests hijau (total 76+) | `6edf686`,`648bcdf`,`81cada9` |
| 2026-08-26 | P3 Auth & Store — **PASS** | Onboarding 3 langkah • PIN hash PBKDF2 injectable (D-022) • biometrik local_auth • DB key random Keystore-wrapped • LockScreen + router gate • 93 tests • apk ✓ | `ad368fc`→`c227a5f` |

| 2026-08-26 | PIN fix (D-023) | PIN tepat 6 digit di semua flow; test diperbarui; APK reinstall | d93d10 |
| 2026-08-26 | P4 Master data - **PASS** | Repo produk agregat+referensi+parties (9 tests) | UI list/search/filter/form/detail/arsip | Pelanggan/Supplier/Salesman/Referensi | Menu Lainnya nyata | 102 tests, apk ✓ | 1a28a40,ce7c67d |
| 2026-08-26 | P5 Inventory - **PASS** | InventoryService atomik (opening/adjustment/opname + guard STOCK_INSUFFICIENT) | UI Stok + Kartu Stok via menu Lainnya | 110 tests, apk ✓, install emulator | 2c010c |

**Status aktual setelah audit 2026-08-28:** milestone P11 tercapai di Git,
tetapi repository berada pada **MVP recovery gate**. Temuan P0 di
`docs/AI_AUDIT.md` wajib diselesaikan dan diverifikasi sebelum Phase 2.

### Audit execution log

| Tanggal | Milestone | Hasil |
|---|---|---|
| 2026-08-28 | Repository audit/read-only | Temuan P0/P1/P2; belum ada perubahan source |
| 2026-08-28 | Local checkpoint | `af4411a` sebelum recovery work |
