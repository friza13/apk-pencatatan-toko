# NOTAKIT — Software Requirements Specification (SRS)

# 5. Software Requirements Specification (SRS)

## 5.1 Functional Requirements

### FR-AUTH-001 Onboarding Owner

Sistem harus memungkinkan user membuat profil owner pertama kali.

Input minimal:
- nama owner;
- nama usaha;
- PIN;
- opsi biometrik;
- timezone;
- currency.

Acceptance:
- hanya satu owner aktif.
- aplikasi dapat dibuka setelah setup tanpa internet.

### FR-STORE-001 Store Profile

Sistem harus menyimpan profil usaha dan menampilkannya pada output nota.

### FR-PROD-001 Product CRUD

Sistem harus menyediakan create/read/update/archive item.

Rules:
- SKU/barcode dapat diberi unique constraint;
- item jasa tidak mengurangi stok;
- non-stock item tidak mengurangi stok;
- item inactive tidak dapat dijual kecuali transaksi historis.

### FR-PROD-002 Variant

Varian dapat memiliki kode/SKU, harga dan stok sendiri atau inherit dari parent.

### FR-PROD-003 Unit Conversion

Sistem harus mendukung conversion factor.

Contoh:

`1 dus = 24 pcs`

Jika dijual 2 dus, stok berkurang 48 pcs base unit.

### FR-PRICE-001 Customer Tier Pricing

Harga dapat ditentukan berdasarkan:
- price tier;
- customer type;
- customer override;
- quantity break opsional.

Prioritas harga:

`customer override > tier/customer type > promo/wholesale rule > standard price`.

### FR-SALES-001 Create Sale

Sistem harus membuat sale dengan immutable transaction number.

Line wajib memiliki snapshot:
- nama produk;
- SKU;
- unit;
- unit price;
- discount;
- tax;
- HPP saat transaksi.

Tujuannya agar histori tidak berubah ketika master produk berubah.

### FR-SALES-002 Payment

Status:

`DRAFT -> OPEN -> PARTIAL -> PAID`

Atau:

`OPEN -> VOID`

Retur tidak menghapus transaksi asal.

### FR-SALES-003 Discount

Dukung:
- nominal;
- persentase;
- bertingkat.

Rumus default diskon bertingkat:

`net = (gross × (1-d1)) × (1-d2) - fixed_discount`

Dengan guard bahwa net tidak boleh negatif.

### FR-STOCK-001 Stock Movement

Setiap perubahan stok harus membuat stock movement.

Tipe minimal:
- PURCHASE_IN;
- SALE_OUT;
- SALES_RETURN_IN;
- PURCHASE_RETURN_OUT;
- ADJUSTMENT_IN;
- ADJUSTMENT_OUT;
- STOCK_OPNAME;
- OPENING_BALANCE.

### FR-STOCK-002 Atomic Transaction

Penyimpanan sale dan stock movement harus satu database transaction.

Tidak boleh ada kondisi:
- nota committed tetapi stok gagal;
- stok berkurang tetapi nota gagal.

### FR-AR-001 Receivable

Jika pembayaran < total, sistem membuat receivable balance.

### FR-CASH-001 Cash Ledger

Setiap payment, expense, income manual dan transfer menghasilkan ledger entry.

### FR-REPORT-001 Reports

Laporan dihitung dari normalized transaction data dan ledger, bukan dari nilai cache tanpa rekonsiliasi.

### FR-PRINT-001 Receipt

Output harus dapat dirender ke:
- thermal 58;
- thermal 80;
- A4;
- PDF.

### FR-BACKUP-001 Full Backup

Backup harus mencakup:
- database;
- schema version;
- app version;
- metadata;
- media references/files yang dipilih;
- checksum.

### FR-BACKUP-002 Encrypted Backup

Format yang disarankan:

```text
.NotaKitbackup
```

Container:

```text
magic
format_version
kdf_parameters
salt
nonce
ciphertext
authentication_tag
checksum/manifest
```

Kriptografi:
- AES-256-GCM untuk confidentiality + integrity;
- Argon2id atau PBKDF2-HMAC-SHA256 untuk derivasi kunci;
- random salt;
- random nonce;
- tidak pernah hard-code key.

### FR-BACKUP-003 Import/Restore

Restore harus melakukan:

1. validate file;
2. decrypt;
3. verify auth tag/checksum;
4. validate schema;
5. preview counts;
6. user confirmation;
7. write to temporary database;
8. integrity checks;
9. atomic replace/merge;
10. create restore audit event.

### FR-AUDIT-001 Activity Log

Operasi berikut minimal diaudit:
- login/unlock;
- create/update/delete/archive product;
- create/edit/void sale;
- payment;
- stock adjustment;
- backup;
- restore;
- import/export;
- settings sensitif.

### FR-MKT-001 Marketplace Import

External order wajib memiliki:
- provider;
- external order ID;
- external order timestamp;
- payload hash.

Unique key:
`provider + external_order_id`.

### FR-NOTIF-001 Notifications

Local notifications:
- stock low;
- due receivable;
- pending online order;
- failed backup;
- backup overdue.

### FR-REST-001 Restaurant Mode

Restaurant order dapat mempunyai table, order type, kitchen status dan split/merge bill.

### FR-MINI-001 Minimarket Mode

Minimarket mode mengutamakan barcode scanning, rapid checkout dan receipt printing.

---

# 6. Non-Functional Requirements

## NFR-001 Performance

- startup cold < 3 detik pada device kelas menengah dengan database normal;
- pencarian produk < 200 ms target pada 10.000 item;
- checkout < 500 ms target setelah scan/input selesai;
- report harian < 2 detik target pada 100.000 sale line dengan indexing yang tepat.

## NFR-002 Reliability

- database transaction atomic;
- WAL mode jika engine mendukung;
- crash-safe commit;
- backup sebelum destructive restore.

## NFR-003 Security

- local DB encrypted;
- secrets di secure storage;
- no plaintext backup password;
- audit trail;
- lock screen;
- least privilege permissions.

## NFR-004 Portability

- Android menjadi platform utama;
- Flutter architecture harus menjaga business logic platform-independent;
- printer abstraction harus memisahkan Android transport dari domain.

## NFR-005 Maintainability

Direkomendasikan:
- Clean Architecture / modular architecture;
- repository pattern;
- use-case/service layer;
- generated DB models;
- unit tests + integration tests.

---

# 16. State Machines

## Sale

```text
DRAFT
  -> OPEN
  -> PARTIAL
  -> PAID
  -> COMPLETED

OPEN/PARTIAL/PAID
  -> VOID (hanya lewat authorized action)

PAID/COMPLETED
  -> RETURNED (melalui return document, bukan delete)
```

## Receivable

```text
OPEN -> PARTIAL -> PAID
OPEN -> OVERDUE
OVERDUE -> PARTIAL -> PAID
```

## Marketplace Order

```text
IMPORTED
 -> CONFIRMED
 -> PACKED
 -> SHIPPED
 -> COMPLETED

IMPORTED -> CANCELLED
```

---

# 20. Error Handling

Setiap use case harus mengembalikan typed result:

```text
Success(data)
Failure(code, message, cause)
```

Error codes minimal:

- AUTH_LOCKED
- INVALID_PIN
- PRODUCT_NOT_FOUND
- PRODUCT_INACTIVE
- STOCK_INSUFFICIENT
- INVALID_QUANTITY
- INVALID_DISCOUNT
- INVALID_PAYMENT
- RECEIVABLE_LIMIT_EXCEEDED
- DUPLICATE_TRANSACTION
- BACKUP_INVALID
- BACKUP_WRONG_PASSWORD
- BACKUP_SCHEMA_UNSUPPORTED
- BACKUP_CORRUPTED
- MARKETPLACE_UNAUTHORIZED
- MARKETPLACE_RATE_LIMITED
- MARKETPLACE_DUPLICATE_ORDER
- PRINTER_NOT_FOUND
- PRINTER_CONNECTION_FAILED
- DATABASE_ERROR

---

# 21. Testing Strategy

## Unit Test

- price calculation;
- discount levels;
- tax;
- rounding;
- unit conversion;
- stock calculation;
- weighted average cost;
- receivable calculation;
- ledger balance;
- report aggregation;
- backup encryption/decryption.

## Integration Test

- create sale + stock + payment atomically;
- partial payment;
- return;
- purchase + stock in;
- restore backup;
- duplicate marketplace order;
- print rendering;
- database migration.

## Golden/UI Test

- thermal 58 receipt;
- thermal 80 receipt;
- A4 invoice;
- dark/light theme;
- barcode checkout.

## Recovery Test

- force-close after transaction;
- battery loss simulation;
- corrupted backup;
- wrong password;
- interrupted restore;
- schema upgrade from v1 to v2.

---

# 22. Acceptance Test Checklist

## Onboarding

- [ ] Owner dapat dibuat tanpa internet.
- [ ] Toko dapat dibuat.
- [ ] PIN dapat dibuat.
- [ ] Biometric dapat diaktifkan.

## Product

- [ ] Barang dapat dibuat.
- [ ] Jasa dapat dibuat.
- [ ] Non-stock dapat dibuat.
- [ ] Barcode dapat disimpan.
- [ ] Varian berfungsi.
- [ ] Satuan dan konversi benar.
- [ ] Harga grosir benar.
- [ ] Harga per tipe pelanggan benar.
- [ ] SKU marketplace tersimpan.
- [ ] Berat/volume tersimpan.
- [ ] Foto/video dapat dikelola.

## Sales

- [ ] Nota dapat dibuat.
- [ ] Discount nominal.
- [ ] Discount persen.
- [ ] Discount bertingkat.
- [ ] Payment penuh.
- [ ] Payment sebagian.
- [ ] Piutang dibuat otomatis.
- [ ] Stok berkurang atomically.
- [ ] Nota dapat dicetak.
- [ ] Nota dapat dibagikan.
- [ ] Void memakai audit.
- [ ] Return tidak menghapus transaksi asal.

## Inventory

- [ ] Stok masuk.
- [ ] Stok keluar.
- [ ] Adjustment.
- [ ] Stock opname.
- [ ] Kartu stok.
- [ ] Nilai stok.
- [ ] Low-stock notification.

## Finance

- [ ] Kas.
- [ ] Bank.
- [ ] Pemasukan.
- [ ] Pengeluaran.
- [ ] Transfer.
- [ ] Piutang.
- [ ] Payment allocation.

## Reports

- [ ] Summary.
- [ ] Rekap harian.
- [ ] Laba penjualan.
- [ ] Laba bersih.
- [ ] Arus kas.
- [ ] Nilai stok.
- [ ] Produk terlaris.
- [ ] Analisa penjualan.
- [ ] Riwayat aktivitas.

## Backup

- [ ] Full export JSON.
- [ ] Full export encrypted.
- [ ] Import backup.
- [ ] Wrong password rejected.
- [ ] Corrupted backup rejected.
- [ ] Schema migration.
- [ ] Restore does not duplicate.
- [ ] User gets preview before destructive restore.

## Marketplace

- [ ] External order import.
- [ ] Income import.
- [ ] SKU mapping.
- [ ] Duplicate prevention.
- [ ] Retry failed sync.
- [ ] Sync log.

## Printer

- [ ] 58mm.
- [ ] 80mm.
- [ ] PDF.
- [ ] A4.
- [ ] Share.
- [ ] Bluetooth where supported.
- [ ] Network/Wi-Fi where supported.
- [ ] USB/OTG where supported by Android/plugin.

---

# 23. Migration & Versioning

Schema memiliki angka:

`schema_version = 1, 2, 3, ...`

Aturan:

- migration harus forward-only;
- setiap release menyimpan migration script;
- backup selalu menyimpan schema_version;
- import lama harus melalui migration sebelum digunakan;
- destructive migration harus membuat backup otomatis.

Contoh:

```text
Backup v1
  -> detect schema v1
  -> migrate v1 -> v2
  -> migrate v2 -> v3
  -> validate
  -> restore
```

---

# 25. Definition of Done

Sebuah fitur dianggap selesai bila:

1. UI selesai.
2. Domain rule selesai.
3. DB schema/migration selesai.
4. Repository selesai.
5. Error state ditangani.
6. Loading state ditangani.
7. Audit log diterapkan untuk operasi sensitif.
8. Unit test tersedia.
9. Integration test tersedia bila menyentuh transaksi.
10. Backup/restore compatibility diuji.
11. Tidak ada data mutation langsung dari widget tanpa melalui use case/repository.

---

# 27. Traceability Matrix Ringkas

| Kebutuhan | Modul | Entitas Utama | Test |
|---|---|---|---|
| Nota | Sales | SALE, SALE_LINE | sales integration |
| Piutang | Receivable | RECEIVABLE | receivable test |
| Stok | Inventory | STOCK_MOVEMENT | inventory test |
| Harga grosir | Pricing | PRICE_TIER, PRODUCT_PRICE | pricing test |
| Pelanggan | CRM | CUSTOMER | customer test |
| Salesman | CRM | SALESMAN | salesman test |
| Laporan | Reporting | SALE, LEDGER, STOCK_MOVEMENT | report test |
| Kas/bank | Finance | ACCOUNT, LEDGER_ENTRY | ledger test |
| Backup | Backup | BACKUP_RECORD | crypto/restore test |
| Marketplace | Integration | MARKETPLACE_* | idempotency test |
| Printer | Output | PRINTER_PROFILE | render test |
| Audit | Security | ACTIVITY_LOG | audit test |

---
