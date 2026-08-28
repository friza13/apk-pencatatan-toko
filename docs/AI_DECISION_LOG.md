# NOTAKIT — AI DECISION LOG

> Setiap keputusan arsitektur/teknis penting dicatat di sini dengan format:
> Context → Options → Decision → Reason → Trade-offs → Consequences.
> Keputusan tidak boleh berubah tanpa entri baru yang merujuk keputusan lama (supersede).

---

## D-028 — Pengaturan profil toko & Pemilihan Varian / Satuan di POS Cart

**Context:** Profil toko belum memiliki UI dan routing dari menu Pengaturan; POS Cart sebelumnya hanya menambahkan produk dasar tanpa picker varian/satuan konversi.

**Decision:** 
1. Menambahkan `StoreProfileScreen` yang terhubung ke database `businesses` untuk mengubah nama toko, nomor telepon, alamat, dan catatan kaki struk (`footerNote`), serta mendaftarkan route `/more/settings`.
2. Menambahkan dukungan varian dan satuan konversi ke `CartLine` dan `CartController` (dengan `cartKey` unik dan getter `displayName`), serta modal bottom sheet di `NewSaleScreen` untuk memilih varian atau satuan alternatif sebelum masuk ke keranjang.
3. Memperbaiki formatting quantity pada struk cetak (`microToDecimalString`) dan parsing desimal pada retur (`toMicro`).

**Reason:** Memenuhi PRD §Q (Store Settings), SRS §FR-STORE-001, SRS §FR-PRINT-001, SRS §FR-PROD-002 / FR-PROD-003, dan memastikan user experience di POS lengkap dan akurat.

**Trade-offs:** Penambahan query detail saat produk dipilih memiliki latency minimal, namun menyediakan opsi varian/satuan secara interaktif.

## D-025 — Checkout menggunakan pricing snapshot ter-resolve

**Context:** Model pricing, variant, dan unit sudah ada, tetapi checkout masih
memakai harga cart tanpa resolusi service-side.

**Decision:** Checkout menyelesaikan customer override, tier/type, quantity
break, validity, wholesale, variant, dan unit conversion di dalam transaksi.
Harga, unit, quantity base, serta cost disalin sebagai snapshot ke sale line.

**Reason:** Mencegah harga dari UI menjadi sumber kebenaran dan menjaga
historical transaction tetap stabil saat master data berubah.

**Trade-offs:** Resolusi menambah query saat checkout; optimisasi batching dapat
ditangani setelah correctness MVP terbukti.

## D-026 — Customer wajib tersedia untuk saldo tertunda

**Context:** Checkout mendukung pembayaran parsial/kredit, tetapi UI belum
menyediakan pemilik piutang.

**Decision:** Payment sheet menampilkan customer aktif dan meneruskan pilihan ke
`CheckoutInput`; service tetap menolak due balance tanpa customer.

**Reason:** Menjaga invariant bahwa setiap receivable memiliki owner.

## D-027 — Kebijakan deferred items dan status verifikasi

**Context:** Beberapa hardening atau QA follow-up tidak termasuk bug aktif atau
blocker MVP.

**Decision:** Item `DEFERRED` tidak diimplementasikan dan tidak menghambat MVP
tanpa instruksi eksplisit. Deferred saat ini adalah return idempotency/retry
safety, refund transaksi dengan banyak metode/akun pembayaran, dan manual
walkthrough UI return di emulator. Phase 2/3 juga tidak dimulai otomatis.

**Reason:** Menjaga scope MVP, mencegah perubahan schema/architecture tanpa
kebutuhan, dan memprioritaskan correctness, data integrity, recovery,
security, regression safety, performance, lalu UX polish.

**Verification language:** Dokumentasi wajib membedakan `VERIFIED NOW`,
`PASSED PREVIOUSLY`, dan `NOT VERIFIED`. Manual walkthrough yang belum
dijalankan dicatat sebagai QA gap, bukan PASS.

**Compatibility requirement:** Jika deferred item dikerjakan setelah ada
instruksi, perubahan harus backward compatible, memakai migration bila
diperlukan, atomic terhadap inventory/payment/ledger/receivable, memiliki
regression test, dan tidak mengubah historical transaction secara diam-diam.

## D-001 — Scope: MVP dulu, Phase 2/3 ditunda

**Context:** PRD memuat fitur sangat luas (restoran, minimarket lanjutan, marketplace). Implementasi semua sekaligus berisiko tinggi.

**Options:** (a) MVP dulu; (b) bangun semuanya sekaligus.

**Decision:** Ikuti batasan MVP PRD §4 (P0–P11), restaurant/minimarket/marketplace = extension point saja, disembunyikan dari UI MVP.

**Reason:** Mengurangi risiko, menghasilkan software jalan lebih cepat, sesuai sprint order arsitektur.

**Trade-offs:** Fitur Phase 2/3 belum bisa dipakai sampai fase masing-masing.

**Consequences:** Schema & struktur feature disiapkan ekstensibel; flag/hide untuk fitur belum matang.

---

## D-002 — Ekstensi backup resmi `.nkb`

**Context:** Konflik antar dokumen (C-01): SRS/ARCH `.NotaKitbackup`, DESAIN `.notakit`, master prompt menyarankan `.nkb`.

**Options:** `.NotaKitbackup` / `.notakit` / `.nkb`.

**Decision:** **`.nkb`** (keputusan owner).

**Reason:** Pendek, konsisten, mudah diasosiasikan.

**Trade-offs:** Perlu amend catatan SRS §FR-BACKUP-002 dan DESAIN §23 (dicatat di discovery C-01).

**Consequences:** Manifest internal WAJIB memuat minimal: `format_version`, `schema_version`, `app_version`, `created_at`, cipher algorithm, KDF algorithm, KDF parameters, salt metadata, nonce/IV metadata, checksum/integrity metadata, encrypted payload metadata. Ekstensi bukan mekanisme keamanan — validasi selalu via magic header + AEAD tag + checksum.

---

## D-003 — Enkripsi database lokal aktif sejak schema v1

**Context:** NFR-003 mewajibkan local DB encrypted. Retrofit enkripsi setelah produksi menyakitkan.

**Options:** (a) SQLCipher-compatible sejak v1; (b) plain SQLite dulu.

**Decision:** (a) Drift + SQLite + SQLCipher-compatible **sejak schema pertama**, dengan GATE: technical spike (Step 6) wajib lulus 8 area uji sebelum full schema. Jika blocker serius → STOP dan laporkan; **tidak ada downgrade silent** ke plaintext.

**Reason:** Keamanan kelas satu sejak hari pertama; migrasi at-rest belakangan = dump/restore penuh + risiko.

**Trade-offs:** Native build Android lebih rumit; ukuran binary bertambah; debugging DB butuh kunci.

**Consequences:** Spike mencakup: open encrypted DB, CRUD, FK, transaction, migration, restart persistence, Android build, interaksi backup/restore.

---

## D-004 — KDF backup: PBKDF2-HMAC-SHA256, configurable, benchmark

**Context:** Butuh derivasi kunci dari password backup; Argon2id berisiko native build di Dart.

**Options:** Argon2id vs PBKDF2-HMAC-SHA256.

**Decision:** PBKDF2-HMAC-SHA256, awal ~600.000 iterasi, **dibenchmark saat spike**, nilai final didokumentasikan. Parameter KDF disimpan di manifest dan dikonsumsi sebagai konfigurasi — tidak hard-code di business logic. Cipher: AES-256-GCM (AEAD). Desain algorithm-agile (field algorithm di manifest).

**Reason:** Murni Dart, stabil lintas platform; manifest agile memungkinkan upgrade Argon2id nanti tanpa break format lama (parameter per-file).

**Trade-offs:** PBKDF2 lebih lemah terhadap GPU dibanding Argon2id pada iterasi sama → kompensasi iterasi tinggi + password policy.

**Consequences:** Restore file lama tetap bekerja karena parameter dibaca per-file; Base64 TIDAK dianggap enkripsi.

---

## D-005 — State management: Riverpod

**Context:** Architecture doc merekomendasikan Riverpod atau Bloc; harus pilih satu.

**Options:** Riverpod / Bloc / Provider.

**Decision:** **Riverpod** (code-genless awal; eval riverpod_generator belakangan bila boilerplate membengkak).

**Reason:** Compile-safe DI, testable tanpa widget, cocok layering UseCase→Repository, kurva belajar lebih landai untuk single dev.

**Trade-offs:** Error-prone bila provider diabuse (mis. business logic di provider) → aturan: logic di domain/usecase, provider hanya orchestration/state.

**Consequences:** Semua feature pakai pola Notifier/AsyncNotifier; no setState untuk state bisnis.

---

## D-006 — Database: Drift + SQLite

**Context:** ERD relational kompleks (±30 tabel, join, transaction, reporting).

**Options:** Drift / Isar / raw SQLite / Hive.

**Decision:** **Drift + SQLite** (+ SQLCipher-compatible per D-003).

**Reason:** Relational penuh: JOIN, FK enforcement, transaction, type-safe queries, migration API, streaming query untuk dashboard.

**Trade-offs:** Boilerplate table definition; build_runner step tambahan.

**Consequences:** WAL mode aktif; foreign_keys pragma ON; index sesuai ERD §15.

---

## D-007 — Payment model: evaluasi generik (OPEN saat desain P1)

**Context:** Amendment #6 melarang merge blind PURCHASE_PAYMENT→PAYMENT; minta evaluasi model generik SALE/PURCHASE/RECEIVABLE/PAYABLE/REFUND/OTHER dengan direction/context/reference eksplisit.

**Decision:** OPEN. Evaluasi dilakukan saat desain schema P1 dengan kriteria: (1) representasi 6 konteks aman, (2) integritas FK, (3) query laporan per metode, (4) dampak ke RECEIVABLE_PAYMENT/PURCHASE_PAYMENT, (5) migrasi backup. Hasil evaluasi WAJIB dicatat sebagai entri baru D-007b sebelum schema final; jika model generik dipilih, ERD diperbarui eksplisit.

**Reason:** Kepatuhan amendment; hindari silent schema change.

**Trade-offs:** Penundaan kecil, tapi schema benar sejak awal.

**Consequences:** Schema payment tidak final sampai D-007b tertulis.

---

## D-008 — Quantity: integer micro-unit scale 10⁶

**Context:** SQLite tak punya DECIMAL; qty bisa pecah (0.5 kg, 1.25 L).

**Decision:** Simpan qty sebagai **integer micro-unit** (`qty_micro = qty × quantity_scale`), konstanta tunggal `quantityScale = 1000000` di core domain (tidak boleh literal tersebar). Konversi tampil/input via Quantity value object.

**Reason:** Deterministik, presisi 6 desimal cukup untuk UMKM, aritmetika integer cepat & exact.

**Trade-offs:** Rentang max ±9.2×10¹² unit dasar (int64) — jauh melampaui kebutuhan.

**Consequences:** Semua kolom qty/cost-per-unit memakai suffix `_micro`; formatter/parsing terpusat.

---

## D-009 — Sales lifecycle: DRAFT → CONFIRMED → PAID / PARTIALLY_PAID / CREDIT

**Context:** Amendment #10; SRS punya enum sedikit beda (C-06).

**Decision:**
```
DRAFT ──finalize──▶ CONFIRMED ──payment penuh──▶ PAID
                       │────payment sebagian──▶ PARTIALLY_PAID ──lunasi──▶ PAID
                       │────tanpa pembayaran, jatuh tempo credit──▶ CREDIT ──▶ PARTIALLY_PAID/PAID
CONFIRMED/PAID/PARTIALLY_PAID/CREDIT ──void──▶ VOIDED
PAID*/CONFIRMED* ──return document──▶ (RETURNED flag/dokumen return terpisah)
```
Aturan: DRAFT tidak mengurangi stok & tidak buat ledger; finalize = atomic commit (sale+lines+payment+ledger+movement+receivable+audit); finalized immutable — edit/delete dilarang; perubahan lewat VOID/RETURN/adjustment. Enum disimpan lowercase snake: `draft, confirmed, paid, partially_paid, credit, voided`. Status `returned` direpresentasikan oleh dokumen SALES_RETURN + flag agregat, bukan menghapus sale asal.

**Reason:** Immutable ledger + workflow perubahan eksplisit = auditable dan sesuai amendment.

**Trade-offs:** Void/return butuh dokumen & alasan; UI harus menyediakan flow tersebut.

**Consequences:** State machine ini menjadi acuan enum DB + guard usecase + test.

---

## D-010 — OVERDUE derived, bukan stored state

**Decision:** Piutang overdue = `due_date < business_now AND outstanding_amount > 0` (business_now = now dalam business timezone). Tidak ada field/status OVERDUE yang di-update manual.

**Reason:** Hindari drift data & job maintenance; rule deterministik dan testable.

**Trade-offs:** Query filter sedikit lebih kompleks; diatasi index `(due_date)` + computed status di repository.

---

## D-011 — Money: integer minor unit + MoneyPolicy terpusat

**Decision:** Semua nominal = integer minor unit (Rp10.500 → `10500`). Satu `MoneyPolicy` domain: rounding mode HALF_UP default; calculation order: line_total = round(qty_base_adjusted × unit_price − line_discount) → subtotal = Σline → diskon nota → pajak atas base setelah diskon → biaya/shipping → pembulatan denomination opsional (nearest 100/500, setting toko, default off) → grand_total. Interaksi pajak-diskon: diskon diterapkan sebelum pajak (tax-exclusive pricing). Guard: grand_total ≥ 0.

**Reason:** Deterministik, testable, bebas floating point.

**Trade-offs:** Perlu disiplin memakai Money type, bukan int mentah, di boundary domain.

---

## D-012 — Timezone: simpan UTC, render business timezone

**Decision:** Semua timestamp DB disimpan UTC (epoch millis / ISO8601 UTC). Presentasi dikonversi memakai business timezone (setting toko, default device tz) via core utility `AppClock`/`AppDateFormatter` — dilarang konversi tersebar di widget. "Hari ini" untuk report = boundary hari business-timezone.

**Reason:** Konsisten untuk backup lintas device/tz; report harian akurat bagi pemilik toko.

**Trade-offs:** Utility wajib dipakai konsisten; diuji dengan DST-less IDR context (Indonesia WIB/WITA/WIT).

---

## D-013 — WAC update atomic on purchase finalize

**Decision:** Saat purchase berstatus draft difinalisasi: satu DB transaction melakukan (purchase+lines persist) → stock movement PURCHASE_IN per line → hitung weighted average cost baru → update cached cost product/variant → ledger bila dibayar. Draft tidak mempengaruhi stok/HPP.

**Reason:** Sesuai amendment #9; HPP stabil dan auditable.

**Trade-offs:** Finalize purchase harus atomic seperti sales; test khusus rollback.

---

## D-014 — Inventory movement ledger = source of truth

**Decision:** Semua perubahan stok wajib menghasilkan baris STOCK_MOVEMENT (PURCHASE_IN, SALE_OUT, SALES_RETURN_IN, ADJUSTMENT_IN/OUT, STOCK_OPNAME, OPENING_BALANCE). Cached balance boleh ada tapi hanya materialized; diverifikasi dari ledger. Dilarang mutasi stok tanpa movement.

**Reason:** Auditability penuh; kartu stok otomatis.

**Trade-offs:** Write lebih banyak; diatasi transaction batch per dokumen.

---

## D-015 — Export: CSV di MVP, XLSX post-MVP

**Decision:** MVP = CSV UTF-8 (delimiter `,`, quoting RFC4180, escape newline/quote, tanggal ISO8601, angka titik desimal agar aman spreadsheet Indonesia; BOM UTF-8 opsional untuk Excel). XLSX tetap di roadmap post-MVP.

**Reason:** Tanpa dependency berat; XLSX butuh library besar yang bisa menyusul.

**Trade-offs:** Format tidak styled; acceptable MVP.

---

## D-016 — Marketplace/Online order: adapter interface saja di v1

**Decision:** Definisikan `MarketplaceAdapter`, `ExternalOrder`, `SyncCursor` interfaces + staging entity concept, TANPA implementasi backend/API di v1. Integrasi eksternal ditunda.

**Reason:** Core local-first; API marketplace butuh approval partner & bisa berubah.

**Trade-offs:** Fitur online belum bisa dipakai; extension point siap.

---

## D-017 — Struktur project: Clean Architecture feature-first

**Decision:**
```
lib/
├── app/          (bootstrap, router, theme)
├── core/         (error, result, money, quantity, datetime, security, database, logging)
├── features/     (dashboard, sales, products, inventory, customers, suppliers, salesmen,
│                  receivables, finance, reports, printing, backup_restore, settings,
│                  security, activity_log, purchases*, marketplace*)
├── database/     (drift tables, dao, appdb)
└── shared/       (widgets NK*, formatters, extensions)
```
(*= folder stub/extension-point di MVP.)

**Reason:** Skala aplikasi besar; feature-first menjaga modul mandiri; sesuai architecture doc.

**Trade-offs:** Banyak folder; diatasi konvensi penamaan ketat.

---

## D-018 — Git checkpoint lokal only

**Decision:** Commit lokal per milestone setelah analyze/test/build lolos; TANPA push/remote kecuali diminta eksplisit owner.

**Reason:** Instruksi owner; jejak milestone rapi.

**Consequences:** Remote setup adalah aksi manual owner di kemudian hari.

---

## Superseded / Rejected

| ID | Topik | Alasan |
|---|---|---|
| — | `.NotaKitbackup` / `.notakit` | Digantikan D-002 |
| — | Merge langsung PURCHASE_PAYMENT→PAYMENT tanpa evaluasi | Ditunda oleh D-007 |
| — | Isar/Hive sebagai DB utama | Tidak relational; D-006 |

## D-025 — Recovery gate: void finansial dibatasi sampai reversal tersedia

**Status:** diterapkan pada recovery MVP (2026-08-28).

**Decision:** `voidSale()` menolak sale yang sudah memiliki payment atau
receivable dengan typed failure sebelum mengubah stok atau status. Refund,
reversal ledger, dan pembatalan receivable penuh tidak boleh disimulasikan
dengan perubahan parsial.

**Reason:** Model receivable saat ini belum memiliki status `voided/cancelled`
dan flow refund belum tersedia. Guard eksplisit mempertahankan invariant bahwa
saldo account, ledger, payment, receivable, dan stok tidak boleh berbeda setelah
operasi void.

**Consequence:** Void hanya aman untuk sale tanpa efek finansial. Implementasi
refund/return lengkap tetap menjadi gate sebelum kebijakan void dapat diperluas.

---

## D-019 — Implementasi D-003: sqlite3mc via build-hook package:sqlite3 v3

**Status:** SPIKE LULUS (2026-08-26, lihat `docs/SPIKE_REPORT.md`). Melengkapi D-003.

**Context:** Rencana awal memakai `sqlcipher_flutter_libs`, tetapi spike menemukan kedua
package `*_flutter_libs` sudah EOL no-op di era `package:sqlite3` v3.

**Decision:**
- Enkripsi DB at-rest = **SQLite3MultipleCiphers (sqlite3mc)**, SQLCipher-compatible,
  AEAD ChaCha20-Poly1305, dipilih via pubspec:
  `hooks.user_defines.sqlite3.source: sqlite3mc`.
- Key diset via setup callback `NativeDatabase`: urutan wajib
  `PRAGMA key → foreign_keys=ON → journal_mode=WAL → query pertama`.
- Verifikasi enkripsi bersifat perilaku (header plaintext check + wrong-key rejection),
  karena build mc ini tidak meng-compile `PRAGMA cipher_version`.

**Reason:** Jalur resmi & maintained (penulis drift), tanpa dual-link ambiguity lama,
tetap memenuhi amendment #2; bukan downgrade ke plaintext.

**Trade-offs:** Tidak bisa probe capability via pragma; format file terikat sqlite3mc
(kompatibilitas SQLCipher klasik tersedia bila diperlukan lewat pragma legacy).

**Consequences:** P1 memakai pola executor dari spike; test header/wrong-key menjadi
regression permanen; drift_dev di-pin 2.34.0 + larangan `textNullable()` (bug codegen).

---

## D-020 — Update D-004: iterasi PBKDF2 final sementara

**Decision:** Default iterasi backup `.nkb` = **600.000** (PBKDF2-HMAC-SHA256, 256-bit key).
Benchmark host debug VM: 100k≈454ms, 200k≈819ms, 400k≈1,614s, 600k≈2,4–2,8s,
800k≈3,2–3,7s. Re-benchmark on-device saat P10; opsi akselerasi `cryptography_flutter`
bila >5 detik di device mid-range. Parameter per-file di manifest → algorithm-agile.

**Consequences:** Nilai TIDAK boleh hard-code di business logic; dibaca dari config
default + ditulis ke manifest setiap backup; restore membaca parameter dari file.

---

## D-021 — Delta schema v1 produksi vs NOTAKIT_ERD.md (transparansi penuh)

**Context:** Amendment #6 melarang perubahan schema senyap. Daftar berikut adalah
seluruh penyimpangan sadar dari ERD asli saat implementasi P1.

| # | Delta | Alasan |
|---|---|---|
| 1 | `PURCHASE_PAYMENT` dihapus; digabung ke `Payments` generik (`purpose='purchase_payment'`, `direction='out'`) | D-007b |
| 2 | `EXPENSE` dihapus; digantung ke `Payments` (`purpose='other_expense'`/`'other_income'` + kolom `category`) — satu jalur ledger | D-007b; FR-CASH-001 tetap terpenuhi |
| 3 | `RECEIVABLE_PAYMENT.payment_id` non-null + RESTRICT | Alokasi tanpa payment tidak bermakna |
| 4 | Semua tabel uang memakai suffix `_minor`; qty `_micro`; konversi satuan disimpan micro-scaled | D-008/D-011, tanpa float |
| 5 | Timestamp = integer epoch-millis UTC via `EpochMillisUtcConverter` | D-012 |
| 6 | Enum disimpan TEXT + CHECK constraint (bukan textEnum) agar format snake_case sesuai D-009 dan stabil untuk backup | Kontrol penuh atas nilai tersimpan |
| 7 | `PRODUCT.sku`/`barcode` nullable + unique index `(business_id, sku/barcode)` | Banyak UMKM kecil tanpa kode; NULL tidak saling bentrok di unique index |
| 8 | `PRODUCT` + cache stok: `stock_quantity_micro` (dan varian) — materialized dari movement ledger | G-01/D-014 |
| 9 | `PRODUCT.cost_price_minor` = WAC berjalan per base unit; diperbarui saat purchase finalize | G-02/D-013 |
| 10 | Berat/volume → integer: `weight_grams`, `volume_ml` | Hindari float; unit eksplisit |
| 11 | `SALE.number` nullable (draft belum bernomor); unique index `(business_id, number)` | Draft tanpa nomor; finalisasi mengisi nomor sekuensial dalam transaction yang sama |
| 12 | `SALE.status` enum baru D-009: draft/confirmed/paid/partially_paid/credit/voided (+ `finalized_at`,`voided_at`) | C-06 amendment #10; RETURNED direpresentasikan dokumen return |
| 13 | `SALE_LINE` + snapshot lengkap amendment #7: `unit_id`, `qty_micro`, `conversion_factor_micro`, `qty_base_micro` | Sejarah imun terhadap perubahan master data |
| 14 | `PAYMENT` + kolom `direction`,`purpose`,`counter_account_id`(transfer),`refund_of_payment_id`(self-ref),`category`; CHECK amount>0 | D-007b & amendment #14 (refund eksplisit ke akun) |
| 15 | `STOCK_MOVEMENT.qty_base_micro` signed; `unit_cost_minor` snapshot; tipe movement sesuai SRS | D-014 |
| 16 | `PURCHASE` + `other_cost_minor` (biaya masuk WAC), `voided_at`; `PURCHASE_LINE` + snapshot konversi | D-013 & amendment #7 |
| 17 | `SALES_RETURN` + `refund_payment_id` nullable (tautan dokumen return → refund payment), `voided_at` | Amendment #14 |
| 18 | Tabel tambahan vs ERD: `PurchaseReturns`+lines (schema-ready Phase 2) | C-04 diselesaikan dengan schema, tanpa UI MVP |
| 19 | `APP_SETTING.value_json` (bukan value_json_encrypted): enkripsi nilai sensitif di application layer | Kunci per-value via secure storage (P3); nama kolom jujur |
| 20 | `ACTIVITY_LOG.device_id` TEXT; `entity_id` TEXT | Fleksibilitas referensi non-integer |
| 21 | Index ERD §15 diadaptasi ke nama kolom baru (@TableIndex) + unique keys per scope bisnis | Konsistensi index strategy |

**Consequence:** Setiap delta di atas bersifat final untuk schema v1; backup `.nkb`
menyimpan schema_version=1 terhadap struktur ini.

---

## D-023 � PIN selalu tepat 6 digit (keputusan owner)

**Context:** Bug UX: lock screen auto-submit di 4 digit sementara PIN onboarding boleh 4-8,
membuat PIN terasa "mengetik sendiri". Owner memutuskan menyamai standar PIN bank.

**Decision:** PAN = **tepat 6 digit angka** di seluruh aplikasi (onboarding, lock screen,
ganti PIN). Validasi `AuthRepository._validatePin` menolak selain 6 digit angka.
LockScreen auto-submit hanya saat `_pin.length == 6`; indikator titik tetap 6.

**Consequences:** Test repository/controller/widget diperbarui; pesan validasi:
"PIN harus tepat 6 digit angka".

## D-024 — Audit recovery gate sebelum Phase 2

**Context:** Audit repository pada 2026-08-28 menemukan perbedaan antara status
MVP di Git dan dokumentasi, serta risiko correctness pada restore, void, dan
credit sale.

**Decision:** Repository tidak boleh masuk Phase 2 sebelum temuan P0 pada
`docs/AI_AUDIT.md` diperbaiki dengan regression test dan diverifikasi ulang.
Status milestone dipisahkan menjadi "pernah pass" (execution history) dan
"diverifikasi ulang" (audit session).

**Reason:** Correctness data dan recoverability lebih penting daripada
menambah fitur baru; commit atau test yang ada tidak membuktikan seluruh
behavior aktual.

**Consequences:** P0 recovery fixes dikerjakan berurutan dengan checkpoint Git
lokal. Setiap fix wajib memiliki test dan verification yang relevan. Temuan P1
tetap menjadi backlog, sedangkan fitur Phase 2/3 tetap deferred.

---

## D-029 — Seamless Initial Stock & Integrated Stock Actions UX

**Context:** Pengguna membutuhkan kemampuan mengisi stok awal secara langsung pada form pendaftaran produk/varian tanpa harus berpindah ke menu lain, serta membutuhkan akses cepat pengaturan stok (tambah/kurang/opname) dan kartu stok langsung dari halaman Detail Produk.

**Decision:**
1. `ProductDraft` dan `VariantInput` mendukung `initialStockMicro`. Saat `ProductRepository.createProduct` dipanggil dengan `trackStock: true` dan `initialStockMicro > 0`, sistem secara atomic membuat mutasi `OPENING_BALANCE` di `stock_movements` dan memperbarui saldo stok (memenuhi `D-014`).
2. Disediakan `StockActionSheet` reusable (`lib/features/inventory/presentation/widgets/stock_action_sheet.dart`) yang mendukung aksi Stok Awal, Tambah, Kurang, Opname, serta pemilihan varian produk.
3. `ProductDetailScreen` menyediakan tombol `[ Atur Stok ]` dan `[ Kartu Stok ]` langsung di kartu Stok, dengan pembaruan reaktif via `productDetailProvider`.
4. `StockScreen` mendukung tap pada seluruh item untuk langsung membuka `StockActionSheet` dengan deteksi varian otomatis.

**Consequences:** Seluruh mutasi stok tetap tercatat 100% pada immutable ledger `stock_movements`. Form produk dan layar detail menjadi jauh lebih intuitif dan terintegrasi.

