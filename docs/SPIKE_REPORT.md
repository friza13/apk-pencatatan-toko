# NOTAKIT — Technical Spike Report: Drift + SQLite Encrypted Database

> Gate sesuai amendment owner #2: laporan ini WAJIB ada sebelum schema produksi (P1) ditulis.
> **VERDICT: PASS — semua 8 area POC lulus di emulator Android. Lanjut ke P1 disetujui secara teknis.**

---

## 1. Lingkungan Uji

| Item | Nilai |
|---|---|
| Tanggal | 2026-08-26 |
| Host | Windows 11 Pro 24H2 |
| Flutter | 3.44.0 stable • Dart 3.12.0 |
| Target uji | Android emulator Pixel_8 (API terpasang), x86_64 |
| Build bukti | `flutter build apk --debug` ✓ dengan `libsqlite3mc.so` ter-bundle |

## 2. Keputusan Teknis Hasil Spike (D-019, melengkapi D-003)

**Stack enkripsi final:** Drift 2.34.x + `package:sqlite3` 3.5.x **build-hook** dengan
`hooks.user_defines.sqlite3.source: sqlite3mc` → **SQLite3MultipleCiphers**
(SQLCipher-compatible, cipher default **ChaCha20-Poly1305**, AEAD).

**Alasan perubahan dari rencana awal (`sqlcipher_flutter_libs`):**
- Investigasi menemukan kedua package `sqlcipher_flutter_libs 0.7.0+eol` dan
  `sqlite3_flutter_libs 0.6.0+eol` adalah **no-op/EOL** ("no longer does anything").
- Jalur resmi 2026 = build hook `package:sqlite3` v3 (didukung penuh drift ≥2.32,
  dokumentasi resmi drift merekomendasikan `sqlite3mc`).
- Tetap memenuhi amendment #2 ("SQLCipher-compatible encrypted database") dan tidak
  ada downgrade ke plaintext — verifikasi enkripsi bersifat perilaku (lihat §4).

## 3. Hasil Per Area (8 area wajib)

| # | Area | Hasil | Bukti |
|---|---|---|---|
| 1 | Open encrypted DB | ✅ | `PRAGMA key` diterapkan pertama via `NativeDatabase` setup; koneksi melayani query |
| 2 | Drift CRUD | ✅ | insert/select/update/delete pada 2 tabel berkaitan |
| 3 | Foreign keys | ✅ | `PRAGMA foreign_keys => 1`; orphan insert (`category_id=9999`) ditolak `FOREIGN KEY constraint failed`; DDL memuat constraint |
| 4 | Transaction | ✅ | rollback penuh saat exception di tengah transaksi; commit utuh saat sukses |
| 5 | Schema migration | ✅ | DB dibuat di v1 (tabel tanpa kolom `note`) → buka sebagai v2 → `ALTER TABLE ADD COLUMN` berjalan, data utuh, kolom baru dapat ditulis |
| 6 | App restart persistence | ✅ | close → buka ulang instance baru pada file sama → data utuh (bukti persistensi file; kill-proses penuh dicakup recovery test P11) |
| 7 | Android build compatibility | ✅ | Gradle assembleDebug sukses; APK memuat `lib/x86_64/libsqlite3mc.so` (~2.2 MB); binding native-assets otomatis |
| 8 | Backup/restore interaction | ✅ | `PRAGMA wal_checkpoint(TRUNCATE)` → copy byte-level file → hapus asli → restore copy → data terbaca dengan passphrase |

**Uji tambahan:**
- **Header anti-plaintext**: 16 byte pertama file ≠ magic `SQLite format 3` → terenkripsi at-rest terbukti.
- **Wrong passphrase**: dibuka dengan kunci salah → gagal akses (SQLITE_NOTADB class error) — salah kunci tidak pernah menghasilkan data sampah senyap.

## 4. Temuan Penting (WAJIB dipatuhi saat implementasi produksi)

1. **Jangan pakai `*_flutter_libs`.** Keduanya EOL no-op. Hanya jalur build-hook.
2. **`PRAGMA cipher_version` TIDAK ter-compile** di build mc ini (string absen dari binary).
   Verifikasi engine harus **behavioral**: header check + wrong-key rejection — sudah menjadi test permanen.
3. **Urutan pragma sakral**: `key` → `foreign_keys=ON` → `journal_mode=WAL` → query pertama.
   Query pertama memaksa I/O sehingga kunci salah gagal di open, bukan di tengah transaksi.
4. **drift_dev di-pin `2.34.0`** (konflik analyzer: drift_dev ≥2.34.1+1 butuh analyzer ^13,
   bentrok toolchain test riverpod/analyzer 12).
5. **Konstruktor legacy `textNullable()` memicu bug codegen drift_dev 2.34.0**
   ("Null is not a subtype of MethodInvocation") → gunakan `text().nullable()()`.
6. **Dua `@DriftDatabase` dalam satu library yang tabelnya berbagi nama SQL merusak generasi**
   (database kedua kosong) → pisah file per database.
7. **FK dengan nilai NULL tidak dilanggar** (standar SQL) — validasi bisnis tetap di domain layer.
8. **Tidak lagi ada `open.overrideFor`** — loading lib ditangani native assets otomatis;
   yang kita kontrol hanya pemilihan sumber via pubspec `hooks`.

## 5. Benchmark KDF Backup (D-004)

PBKDF2-HMAC-SHA256 (paket `cryptography`, pure Dart) — host Windows, debug VM:

| Iterasi | Waktu |
|---|---|
| 100.000 | ~454 ms |
| 200.000 | ~819 ms |
| 400.000 | ~1.614 ms |
| 600.000 | ~2.416–2.755 ms |
| 800.000 | ~3.207–3.731 ms |

**Keputusan:** default iterasi backup = **600.000** (nilai awal amendment #3 dipertahankan).
Operasi backup/restore jarang terjadi sehingga 1–3 detik dapat diterima; release AOT +
device riil akan divalidasi ulang di P10 (roadmap: opsi akselerasi `cryptography_flutter`
bila >5 detik di device mid-range). Parameter tersimpan per-file di manifest `.nkb`
→ peningkatan iterasi/algoritma di masa depan tidak merusak file lama (algorithm-agile).

## 6. Versi Terkunci untuk P1

```
drift 2.34.3 • drift_dev 2.34.0 (pin) • build_runner 2.15.1
sqlite3 3.5.2 (+ sqlite3mc bundle) • drift_flutter 0.3.1
path_provider 2.1.6 • cryptography 2.9.0
```

## 7. Artefak

- `lib/spike/spike_database.dart` — schema v2 + executor terenkripsi (pola pembuka DB produksi)
- `lib/spike/spike_database_legacy.dart` — seed v1 untuk uji migrasi
- `integration_test/spike_encrypted_db_test.dart` — 9 test (permanen, jadi regression suite)
- `test/spike/kdf_benchmark_test.dart` — benchmark KDF

Setelah P1 selesai, folder `lib/spike/` diganti database produksi; integration test
migrasi jadi template harness migrasi skema.
