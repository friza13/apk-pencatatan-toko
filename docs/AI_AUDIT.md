# NotaKit — Audit & Recovery Report

**Tanggal audit:** 2026-08-28  
**Mode:** read-only investigation  
**Ground truth:** repository source, tests, integration tests, `/docs`, Android configuration, and Git history

## 1. Kondisi repository

NotaKit adalah aplikasi Flutter Android local-first dengan Riverpod, go_router,
Drift/SQLite, SQLite3MultipleCiphers, secure storage, local_auth, PDF/printing,
dan encrypted `.nkb` backup. Repository memiliki 83 file Dart di `lib/`, 25
unit/widget tests, dan 2 integration tests.

Working tree bersih sebelum audit. Checkpoint lokal audit dibuat pada commit
`af4411a` (`chore: checkpoint before MVP audit recovery`). Tidak ada push.

## 2. Milestone aktual

Git history menunjukkan P0 sampai P11 telah dikerjakan:

- P0–SPIKE–P5: foundation, encryption spike, schema, domain, auth, master data, inventory.
- P6: atomic checkout, sales list/detail/void.
- P7: receivable settlement dan finance ledger.
- P8: reports, dashboard KPI, chart, CSV.
- P9: receipt 58/80, PDF, share/print flow.
- P10: encrypted `.nkb`, inspect, preview, restore staging.
- P11: recovery integration test, demo data, 10k-product performance sanity.

Kesimpulan **MVP DONE** didukung oleh commit `65c9cc8`, tetapi status tersebut
belum dapat disebut release-stable karena audit menemukan isu correctness dan
recovery yang belum diuji ulang pada sesi ini.

## 3. Dokumentasi versus implementasi

`docs/IMPLEMENTATION_PLAN.md` masih berhenti pada checkpoint P5 dan menandai
P8–P11 sebagai pending. Ini adalah **dokumentasi stale**, bukan bukti bahwa
fitur belum ada. Execution log perlu diselaraskan dengan Git.

Dokumen lama juga memuat istilah yang sudah digantikan oleh keputusan baru:
`.NotaKitbackup`/`.notakit` versus `.nkb`, `sqlcipher_flutter_libs` versus
`sqlite3mc`, dan state sale lama versus state D-009. Decision log sudah
mendokumentasikan sebagian besar perubahan tersebut.

## 4. Temuan P0 — harus diperbaiki sebelum release MVP

### P0-1 — Restore dari onboarding tidak pernah dipanggil

**Jenis:** bug nyata  
**Bukti:** `onboarding_screen.dart` mendeklarasikan pilihan kosong/demo sebagai
`0/1`, radio restore memakai nilai `1`, tetapi `_onContinue()` hanya memanggil
`_importBackup()` ketika `_dataChoice == 2`.

**Dampak:** user yang memilih “Pulihkan dari file backup” dapat melewati jalur
restore dan berakhir pada onboarding biasa/demo. Ini merusak alur device
migration dan berpotensi membuat user mengira data telah dipulihkan.

### P0-2 — Sale kredit tanpa customer kehilangan piutang

**Jenis:** bug data integrity  
**Bukti:** `SalesService.checkout()` menghitung `due > 0`, tetapi hanya membuat
`Receivable` jika `input.customerId != null`. UI checkout saat ini tidak memilih
customer, sementara pembayaran di bawah total tetap diizinkan.

**Dampak:** sale berstatus `credit`/`partially_paid` dapat memiliki `dueTotalMinor`
positif tanpa baris receivable. Piutang tidak dapat ditagih melalui UI dan angka
finance/report menjadi tidak lengkap.

**Rekomendasi:** reject unpaid checkout tanpa customer dengan typed failure, atau
buat customer umum yang eksplisit. Jangan membiarkan transaksi committed dalam
kondisi tidak terlacak.

### P0-3 — Void sale tidak membalik kas, payment, dan receivable

**Jenis:** bug data integrity  
**Bukti:** `voidSale()` mengembalikan stok dan mengubah status sale, tetapi tidak
membuat refund/reversal payment, tidak membalik ledger/account balance, dan tidak
menutup atau membatalkan receivable. Komentar service sendiri menyebut cash
reversal sebagai simplifikasi, tetapi P7 sudah tersedia.

**Dampak:** setelah void sale lunas, saldo kas tetap terlalu tinggi. Setelah void
sale kredit, receivable tetap outstanding. Laporan dan audit finansial tidak
konsisten dengan status transaksi.

### P0-4 — Restore bukan atomic swap yang sebenarnya

**Jenis:** bug recovery  
**Bukti:** `applyRestore()` memvalidasi staging lalu menghapus target aktif dengan
`target.delete()` sebelum `staging.rename(targetDbPath)`.

**Dampak:** crash, battery loss, atau proses mati di antara delete dan rename
dapat meninggalkan aplikasi tanpa database. Ini bertentangan dengan requirement
atomic replace/restore transactional.

### P0-5 — Restore flow memutus koneksi DB tanpa verifikasi lifecycle

**Jenis:** bug/risiko lifecycle  
**Bukti:** UI memakai `ref.invalidate(appDatabaseProvider)` lalu langsung
menjalankan operasi file. Invalidasi provider tidak menjadi bukti bahwa koneksi
lama sudah selesai ditutup sebelum file ditimpa; `onDispose(db.close)` bersifat
async dan tidak di-await oleh caller.

**Dampak:** file lock, WAL/SHM tersisa, atau restore pada koneksi lama dapat gagal
atau menghasilkan perilaku platform-dependent.

## 5. Temuan P1 — penting tetapi tidak langsung memblokir MVP

### P1-1 — Quantity conversion dan variant belum terhubung ke checkout

`SaleLineInput` hanya menerima `productId`, `variantId`, qty, dan harga; service
selalu menyamakan `qtyBaseMicro = qtyMicro` dan `conversionFactorMicro =
quantityScale`. Ini belum memenuhi conversion unit/variant yang sudah tersedia
di master data.

### P1-2 — Stock valuation kehilangan pecahan unit

`ReportRepository.stockValuationMinor()` menggunakan pembagian integer
`stockQuantityMicro ~/ quantityScale`, sehingga stok 0,5 unit dinilai sebagai
0 unit. Ini melanggar precision policy untuk quantity micro-unit.

### P1-3 — Production migration harness belum ada

`AppDatabase.schemaVersion` masih 1 dan `migration` hanya mengatur foreign key
di `beforeOpen`; tidak ada `onUpgrade`/fixture migration untuk database produksi.
Spike memiliki migration v1→v2, tetapi belum dipindahkan menjadi harness produksi.

### P1-4 — Backup temp snapshot tidak dibersihkan

`BackupService.createBackup()` membuat file `*.backup-*.tmp` dan memiliki
`finally` kosong. Backup berulang dapat meninggalkan file database snapshot
besar di storage.

### P1-5 — Backup menggunakan metadata runtime yang hard-coded

`DataScreen` mengirim `schemaVersion: 1` dan `appVersion: '1.0.0-dev'` alih-alih
mengambil versi/schema dari satu sumber runtime. Ini berisiko menghasilkan
manifest yang salah setelah release atau schema upgrade.

### P1-6 — Overpayment dan pembayaran negatif pada checkout disilent clamp

`paidNowMinor` diproses dengan `.clamp(0, grandTotalMinor)`. Input negatif
menjadi nol dan overpayment dipotong ke total, padahal SRS mendefinisikan
`INVALID_PAYMENT`. Data terlihat sukses meski input invalid.

### P1-7 — Pricing engine belum dipakai oleh flow sales

`PricingEngine` dan test-nya ada, tetapi cart memakai `salePriceMinor` langsung
dan checkout menerima harga dari UI. Customer type, tier, override, dan quantity
break belum menjadi bagian dari jalur pembuatan nota aktual.

## 6. Temuan security

- Positif: DB key random disimpan melalui secure storage; PIN memakai salted
  PBKDF2; backup memakai AES-256-GCM dan checksum; password tidak ditaruh di
  manifest plaintext.
- P1: `BackupCrypto.decrypt()` melakukan `sublist()` sebelum validasi panjang
  blob. Container malformed dapat menghasilkan `RangeError` yang salah
  diklasifikasikan sebagai wrong password karena `inspect()` menangkap semua
  `Object`.
- P1: `applyRestore()` menguji database staging dengan `dbPassphrase`, tetapi
  tidak menjalankan seluruh urutan pragma production (`key`, foreign keys,
  WAL, forced probe) secara konsisten.
- P2: beberapa controller menangkap exception secara luas dan mengubahnya menjadi
  state generik. Ini menjaga UI tetap hidup, tetapi menyulitkan diagnosis dan
  dapat menyembunyikan error platform.

## 7. Temuan UX/navigation

- Positif: bottom navigation memiliki lima destinasi, menu sekunder Phase 2/3
  disembunyikan, dan layar utama memiliki empty state dasar.
- P1: checkout tidak memiliki pemilihan customer, padahal partial payment
  membutuhkan customer agar piutang dapat dilacak.
- P1: settings/toko saya belum menjadi route nyata; menu Pengaturan hanya
  menampilkan snackbar “menyusul”.
- P1: restore di `DataScreen` menampilkan preview setelah password, tetapi
  belum memakai confirmation terpisah setelah preview sebelum destructive swap.
- P2: banyak layar belum memiliki loading/error/empty state yang setara sesuai
  Definition of Done desain.

## 8. Temuan performance

- Test 10k produk hanya memberi threshold longgar `<2s`, sedangkan requirement
  target adalah `<200ms`; hasil pengukuran aktual tidak tersimpan di docs.
- Test memasukkan 10.000 produk satu per satu dan komentar batch tidak benar-benar
  membungkus seluruh insert dalam satu transaction. Ini mengurangi kualitas
  benchmark.
- Report harian melakukan query per hari dalam loop. Untuk rentang panjang,
  agregasi tunggal akan lebih stabil.

## 9. Deferred / bukan bug MVP

Hal-hal berikut memang ditunda sesuai D-001/D-016 dan tidak perlu diperlakukan
sebagai regression MVP:

- restaurant/cafe mode;
- minimarket mode lanjutan;
- marketplace adapters dan online order;
- Google Drive/cloud sync;
- purchase workflow lanjutan, purchase return UI, batch/expiry;
- advanced accounting dan cross-device realtime sync;
- printer transport BLE/Wi-Fi/USB spesifik perangkat.

## 10. Status verifikasi

Commit history menunjukkan milestone sebelumnya pernah menjalankan analyzer,
test, APK build, dan integration test. Namun pada audit ini rerun `flutter
analyze` dan `flutter test` ditolak oleh permission environment, sehingga status
tersebut harus disebut **pernah pass**, bukan **diverifikasi ulang sekarang**.
Integration test dan debug build juga belum dapat dieksekusi ulang pada sesi ini.

## 11. Prioritas recovery

1. **P0:** perbaiki restore onboarding dan tambahkan regression test.
2. **P0:** cegah sale unpaid tanpa customer; tambahkan test data-integrity.
3. **P0:** implementasikan reversal void untuk kas/ledger/receivable atau
   batasi void secara eksplisit sebelum settlement; tambahkan test.
4. **P0:** ubah restore menjadi replacement yang crash-safe dan pastikan koneksi
   DB benar-benar tertutup.
5. **P1:** hubungkan pricing/conversion ke checkout, perbaiki stock valuation,
   migration harness, cleanup temp backup, dan runtime metadata.
6. **P2:** rapikan error taxonomy, UX states, benchmark, dan README.
7. **Deferred:** jangan mulai Phase 2 sebelum seluruh P0 selesai dan diverifikasi
   ulang.
