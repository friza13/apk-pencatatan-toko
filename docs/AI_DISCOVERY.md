# NOTAKIT — AI DISCOVERY (Phase 0 Baseline)

> Dokumen ini adalah hasil discovery/grounding sebelum satu baris kode produksi ditulis.
> Status: BASELINE Phase 0. Akan diperbarui setiap kali ada keputusan baru (lihat `docs/AI_DECISION_LOG.md`).

---

## 1. Baseline

| Item | Nilai |
|---|---|
| Tanggal discovery | 2026-08-25 |
| Host | Windows (win32) |
| Flutter | 3.44.0 stable |
| Dart | 3.12.0 stable |
| Target | Android v1 (iOS/desktop ditunda) |
| Status repository saat discovery | Documentation-only (belum ada project Flutter, belum git repo) |

## 2. Document Set Saat Discovery

| File | Peran | Status |
|---|---|---|
| `docs/NOTAKIT_PRD.md` | PRD: tujuan, persona, fitur A–R, non-goals, success criteria, MVP vs Phase 2/3 | Lengkap |
| `docs/NOTAKIT_SRS.md` | FR/NFR, state machine, error codes, testing strategy, acceptance checklist, migration & versioning | Lengkap |
| `docs/NOTAKIT_ERD.md` | ±30 entitas + field schema, aturan money/qty/soft-delete, index strategy, HPP WAC | Lengkap dengan beberapa gap |
| `docs/NOTAKIT_SYSTEM_ARCHITECTURE.md` | Layering, stack rekomendasi, spesifikasi backup container, security architecture, IA UI, sprint order | Lengkap |
| `docs/NOTAKIT_DFD.md` | Context diagram, DFD Level 0, DFD penjualan & backup, core workflow | Lengkap |
| `docs/DESAIN.md` | Design system: warna, tipografi Inter, spacing 4pt, radius, navigasi 5 tab, POS UX, komponen NK*, aksesibilitas | Lengkap |
| `docs/NOTAKIT_CLONE_PRD_SRS_ERD_ARCH_DFD.md` | Gabungan dokumen di atas; tidak ada konten unikal baru | Referensi saja |

## 3. Grounding Report

### A. Apa itu NotaKit?
Aplikasi POS/nota + manajemen usaha UMKM: **local-first, offline-first, single-owner**, tanpa subscription/SaaS/multi-tenant. Database lokal adalah source of truth.

### B. Siapa target user?
Owner UMKM tunggal: toko retail, grosir/distributor kecil, minimarket, restoran/cafe, laundry, bengkel, usaha jasa, toko online omnichannel.

### C. Masalah yang diselesaikan
Nota cepat (≤30 detik), omzet/laba transparan, stok terkontrol, piutang terkelola, cetak/share nota, backup & pindah HP mandiri tanpa server developer.

### D. Fitur utama
Penjualan/nota atomik, produk (varian/satuan/konversi/tier harga), inventory movement ledger, piutang, kas/bank ledger, laporan (omzet/laba/arus kas/nilai stok), thermal 58/80 + PDF/share, backup terenkripsi `.nkb`, marketplace adapter (deferred).

### E. Arsitektur aplikasi
Clean Architecture feature-first:
`UI → Controller/Riverpod → UseCase → Domain rules → Repository → Drift/SQLite`
Adapter interfaces untuk printer/marketplace/notification/secure-storage.

### F. Database
SQLite via Drift, **dienkripsi SQLCipher-compatible sejak schema v1** (keputusan D-003). Uang = integer minor unit; qty = integer micro-unit scale 10⁶; master data soft-delete/archive; transaksi final tidak boleh dihapus; FK enforcement aktif; index sesuai ERD §15.

### G. Data flow (inti)
Satu DB transaction per finalisasi penjualan: sale + sale lines (snapshot) + payment(s) + ledger entries + stock movements + receivable (bila ada sisa) + activity log. Commit atau rollback utuh — tidak boleh partial.

### H. UX/UI
Sumber: `DESAIN.md`. Primary Indigo `#2563EB`, font Inter, spacing 4pt, bottom nav 5 tab (Beranda/Penjualan/Produk/Laporan/Lainnya), "Buat Nota" = CTA utama, empty/loading/error state wajib, dark mode setelah light stabil, komponen reusable prefix `NK`.

### I. Constraint teknis
Android primary; core 100% offline; cold start <3s; search <200ms @10k produk; checkout <500ms; report harian <2s @100k line; WAL; crash-safe commit.

### J. Constraint bisnis
No subscription, no SaaS account, no multi-tenant, no server wajib. Backup file = mekanisme resmi pindah device.

### K. Yang tidak boleh dilakukan
- Menghapus transaksi final (harus void/return).
- UI langsung mengakses database.
- Floating point untuk uang.
- Hard-code key/password; Base64 sebagai enkripsi.
- Menyebarkan nama selain **NotaKit** (bukan e-Nota/ENOTA/Clone).
- Membuang fitur hanya karena sulit; mengubah schema tanpa migration.
- Menampilkan fitur Phase 2/3 yang belum matang di UI MVP.

## 4. Feature Inventory MVP (dari PRD §4)

Onboarding owner • profil toko • produk/item (barang/jasa/non-stock) • kategori • satuan & konversi • pelanggan & tipe pelanggan • supplier • salesman • harga grosir/tier • penjualan/nota • pembayaran • piutang • stok • penyesuaian stok • laporan dasar • kas/bank • print 58/80mm + PDF/share • export/import full backup terenkripsi • app lock • audit log • settings.

**Ditunda (Phase 2/3):** restoran/cafe mode, minimarket lanjutan, purchase workflow lanjutan, stock opname lanjutan, Google Drive backup, online order, marketplace adapter, kitchen printing, advanced analytics, sync lintas device, batch/expiry.

## 5. Requirement Traceability (pola wajib)

Setiap FR yang diimplementasikan wajib dilacak penuh:

```
FR-XXX-nnn → UseCase → Domain Entity → Repository → Service Layer → UI → Tests
contoh: FR-SALES-001 → CreateSaleUseCase → Sale → SaleRepository
        → SalesTransactionService → CheckoutScreen → create_sale_test + inventory_impact_test
```

Matriks lengkap per fase dicatat dalam `IMPLEMENTATION_PLAN.md` dan diperbarui saat implementasi.

## 6. Discovered Gaps (requirement yang hilang dari dokumen asli)

| # | Gap | Resolusi |
|---|---|---|
| G-01 | `PRODUCT` tidak punya field stok (hanya `PRODUCT_VARIANT.stock_quantity`); UI menuntut stok level produk | Tambah cached balance `stock_quantity_micro` pada product/variant sebagai materialized view dari movement ledger; rekonstruksi dari ledger |
| G-02 | Formula WAC ada, tapi tidak dispesifikkan kapan `cost_price` diperbarui | WAC update atomic saat purchase FINALIZE (amendment #9 / D-013) |
| G-03 | Transfer antar akun: pola double-entry (2 ledger entry) belum dispesifikasi | Ditambahkan pada desain P7: satu transfer = 2 ledger entry berpasangan |
| G-04 | Rekonsiliasi `ACCOUNT.current_balance` vs `LEDGER_ENTRY` | current_balance adalah cache; validasi = Σ(opening + entries); diverifikasi saat report/rekonsiliasi |
| G-05 | OVERDUE: state tersimpan atau derived? | Derived: `due_date < business_now AND outstanding > 0` (D-010) |
| G-06 | "Edit nota" vs snapshot immutable | Edit hanya DRAFT; setelah finalize → VOID/RETURN (D-009) |
| G-07 | Rumus pembulatan IDR belum ada | Centralized MoneyPolicy: rounding mode + denomination opsional (D-011) |
| G-08 | Timezone strategy belum eksplisit | Simpan UTC; render pakai business timezone via core utility (D-012) |
| G-09 | SALE_LINE belum memuat conversion factor/base qty snapshot (amendment #7) | Schema v1 memuat: unit snapshot, qty, qty_base, conversion_factor, harga/diskon snapshot |
| G-10 | Refund flow (amendment #14): referensi sale/payment asal, akun tujuan eksplisit, impact ledger+inventory+audit atomic | Diimplementasikan P6/P7 sebagai dokumen refund terpisah |
| G-11 | Manifest `.nkb` minimal fields (amendment #1) | Masuk spesifikasi backup P10 |
| G-12 | CSV harus UTF-8 + escaping + kompatibel spreadsheet Indonesia | Ditulis sebagai unit test khusus di P8/P9 reporting/export |

## 7. Requirement Conflicts

| # | Konflik | Sumber | Resolusi |
|---|---|---|---|
| C-01 | Ekstensi backup: `.NotaKitbackup` (SRS/ARCH) vs `.notakit` (DESAIN) vs `.nkb` (master prompt) | SRS §FR-BACKUP-002 / DESAIN §23 | **`.nkb`** (keputusan user, D-002) |
| C-02 | PAYMENT vs PURCHASE_PAYMENT redundan | ERD | Evaluasi model payment generik (SALE/PURCHASE/RECEIVABLE/PAYABLE/REFUND/OTHER) dengan direction/context/reference eksplisit — diputuskan saat desain schema P1, tidak silent (D-007) |
| C-03 | Restaurant mode butuh entitas meja/split-bill; ERD hanya punya `SALE.order_type` | PRD I vs ERD | Deferred Phase 2; extension point disiapkan, tidak masuk MVP UI |
| C-04 | Konsinyasi (PRD B) & purchase return document tidak punya entitas ERD | PRD vs ERD | Deferred; dicatat sebagai future schema |
| C-05 | "Restore parsial" (PRD O) vs MVP full-backup only | PRD internal | Full restore saja di MVP; parsial post-MVP |
| C-06 | State machine SRS (`OPEN/PARTIAL/PAID`) vs amendment (#10 `CONFIRMED/PAID/PARTIALLY_PAID/CREDIT`) | SRS §16 vs amendment | Ikuti amendment (D-009); enum DB dirancang agar kompatibel konsep SRS |

## 8. Risks

### Architecture
- **SQLCipher × Drift**: integrasi native build Android bisa gagal → MITIGASI: technical spike WAJIB sebelum schema produksi (Step 6); jika blocker serius → STOP dan laporkan, tidak downgrade silent.
- **Thermal printer transport** package rawan unmaintained → abstraksi PrinterAdapter; PDF/share solid duluan; transport BLE/WiFi belakangan.

### Database
- Qty desimal → integer micro-unit scale 10⁶ (D-008), tanpa menyebarkan literal 1_000_000.
- Nomor nota sequence harus digenerate dalam transaction yang sama dengan insert sale.
- Migration harness harus siap sehari pertama (schema_version = 1).

### UX
- Layar Buat Nota = risiko terbesar; target ≤4 tap sampai bayar (DESAIN §12). Diukur lewat widget test alur checkout.

### Security
- PIN app-lock ≠ kunci DB. Kunci DB acak, dibungkus secure storage/Keystore; password backup independen; verifikasi AEAD tag sebelum pakai plaintext.
- PBKDF2 iterations ~600k awal; dibenchmark saat spike; parameter dikonfigurasi via manifest (D-004).

## 9. Unresolved Decisions (terbuka saat baseline)

| ID | Topik | Kapan diputuskan |
|---|---|---|
| U-01 | Model payment generik vs tabel terpisah (C-02) | Desain schema P1 |
| U-02 | Iterasi PBKDF2 final | Benchmark spike (Step 6) |
| U-03 | Package transport printer (BLE/WiFi) | P9 |
| U-04 | Library chart (fl_chart vs custom) | P8 |
| U-05 | Nama package/aplikasi Flutter (`notakit`) + applicationId | Step 3 (default: `com.notakit.app`) |

## 10. Kesimpulan

Dokumentasi cukup matang untuk mulai implementasi bertahap dengan amendment engineering dari owner.
Semua gap/konflik sudah punya resolusi terdokumentasi atau jadwal keputusan.
Tidak ada blocker untuk memulai Step 2 (git init) dan Step 3 (foundation Flutter),
dengan syarat spike SQLCipher (Step 6) menjadi gate sebelum schema produksi.
