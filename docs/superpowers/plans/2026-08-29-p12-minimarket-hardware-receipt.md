# NotaKit P12: Minimarket, Purchase Workflow, Advanced Receipt & Hardware Printing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement **P12 (Phase 2)** features for NotaKit: Fast Minimarket Cashier Workflow (HID Barcode & quick cash), Advanced 2-Line Receipt Customization (matching the *Puri Abadi* sample), Direct ESC/POS Thermal Printing (Bluetooth & USB), Purchase & Accounts Payable Workflow (WAC cost update), Google Drive Encrypted Backup, and Advanced Business Analytics.

**Architecture:** Clean Architecture feature-first: Domain rules (integer micro/minor units) $\rightarrow$ Repositories & Services (atomic Drift ledger transactions) $\rightarrow$ Riverpod State Notifiers $\rightarrow$ UI presentation with hardware abstraction adapters for ESC/POS & Barcode Scanner.

**Tech Stack:** Flutter 3.44.0 / Dart 3.12.0, Drift (SQLite/SQLCipher), Riverpod, go_router, `pdf` / `printing`, `flutter_bluetooth_serial` / `esc_pos_utils_plus` / `usb_serial` (or native stream adapters), `googleapis` / `google_sign_in` (Google Drive backup).

**Spec:** `docs/NOTAKIT_PRD.md`, `docs/NOTAKIT_SRS.md`, `docs/DESAIN.md`, `docs/AI_DECISION_LOG.md`, and owner reference receipt sample.

---

## Global Constraints

- **Single-Owner & Offline-First:** Core operations (sales, cashier, stock, purchase, reports, printing) must work 100% offline without mandatory cloud connection.
- **Currency & Money Integrity:** Money values are strictly integer minor units (`Rp10.500 -> 10500`). Zero floating-point arithmetic for financial calculations.
- **Quantity Scale:** Quantities are strictly integer micro-units (`quantityScale = 1000000`).
- **Single Source of Truth Ledger (`D-014`):** All inventory mutations (sale, purchase, adjustment, opname) must write to immutable `stock_movements`.
- **Scope Exclusion:** ❌ **Mode Restoran / Kafe / F&B & Kitchen Printing** are completely removed from P12 scope.
- **Backward Compatibility:** Database migrations must not break existing schema v1 or `.nkb` encrypted backup compatibility.

---

## User Review Required

> [!IMPORTANT]
> **Receipt Template Customization (Based on *Puri Abadi* Sample):**
> The receipt rendering is designed with a 2-line per item format:
> - **Line 1:** Product name & variant (left) $\rightarrow$ Line subtotal (right, bold).
> - **Line 2:** `[Qty] [Unit] X [UnitPrice]` (e.g. `75 crt X 44.800`).
> - **Summary:** Total physical items count (`ITEM: 130`), `JUMLAH TOTAL`, Paid, Change/Due.
> - **Footer:** Custom message, Shop Signature Box, and Dynamic QR Code.
>
> All elements are configurable in **Pengaturan $\rightarrow$ Desain Nota** (can toggle store tagline, operator name, item count, signature box, QR code).

> [!NOTE]
> **Hardware Fallback:**
> If a Bluetooth or USB thermal printer is not connected, the app seamlessly falls back to the system Print Dialog & PDF Share.

---

## Proposed Tasks & TDD Execution

---

### Task 1: Canonical Receipt Model, 2-Line Renderer & Visual Preview (Matching Sample)

**Files:**
- Create: `lib/features/printing/domain/receipt_config.dart`
- Create: `lib/features/printing/domain/receipt_document.dart`
- Modify: `lib/features/printing/data/receipt_text_renderer.dart`
- Modify: `lib/features/printing/data/receipt_pdf.dart`
- Modify: `lib/features/printing/presentation/print_sheet.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Test: `test/features/printing/receipt_document_renderer_test.dart`

**Interfaces:**
- `ReceiptConfig`: `{ bool showTagline, bool showOperator, bool showItemCount, bool showSignature, bool showQr, String? customFooter, String? qrPayload }`
- `ReceiptDocument.fromSale(SaleAggregate sale, Business business, ReceiptConfig config)`
- Produces: Structured receipt payload for graphical preview, high-res PDF generation, and thermal printing.

- [ ] **Step 1: Write failing test for 2-line receipt layout, item count, and signature/QR tokens**
- [ ] **Step 2: Run test to verify RED**
- [ ] **Step 3: Implement `ReceiptConfig` and `ReceiptDocument` with 2-line item layout and QR/signature support**
- [ ] **Step 4: Update `ReceiptPdf` to render modern graphical thermal PDF with signature box and QR**
- [ ] **Step 5: Update `PrintSheet` with live receipt preview**
- [ ] **Step 6: Run test to verify GREEN**
- [ ] **Step 7: Commit Task 1**

---

### Task 2: ESC/POS Thermal Printer Adapter (Bluetooth & USB)

**Files:**
- Create: `lib/features/printing/data/esc_pos_builder.dart`
- Create: `lib/features/printing/data/printer_adapter.dart`
- Create: `lib/features/printing/presentation/printer_settings_screen.dart`
- Test: `test/features/printing/esc_pos_builder_test.dart`

**Interfaces:**
- `PrinterAdapter`: `Future<List<PrinterDevice>> scan()`, `Future<void> connect(PrinterDevice device)`, `Future<void> print(List<int> bytes)`
- `EscPosBuilder`: Encodes `ReceiptDocument` to 58 mm (32 columns) and 80 mm (48 columns) raw byte commands (bold text, alignment, dividers, feed, cut).

- [ ] **Step 1: Write failing test for `EscPosBuilder` generating valid ESC/POS byte sequences**
- [ ] **Step 2: Run test to verify RED**
- [ ] **Step 3: Implement `EscPosBuilder` and mockable `PrinterAdapter`**
- [ ] **Step 4: Create `PrinterSettingsScreen` for discovery, test print, and paper size selection**
- [ ] **Step 5: Connect `PrintSheet` to trigger direct ESC/POS print with fallback to PDF**
- [ ] **Step 6: Run test to verify GREEN**
- [ ] **Step 7: Commit Task 2**

---

### Task 3: Fast Minimarket Cashier & HID Barcode Scanner Workflow

**Files:**
- Create: `lib/features/sales/presentation/widgets/barcode_scanner_listener.dart`
- Modify: `lib/features/sales/presentation/new_sale_screen.dart`
- Modify: `lib/features/sales/controllers/cart_controller.dart`
- Test: `test/features/sales/fast_cashier_barcode_test.dart`

**Interfaces:**
- `BarcodeScannerListener`: Listens to raw key events from USB/Bluetooth handheld barcode scanners (captures buffered characters until Enter/newline).
- Auto-adds matched product/variant to cart with quantity increment $+1$.
- `NewSaleScreen` adds Quick Cash buttons: `[Uang Pas]`, `[+Rp10.000]`, `[+Rp20.000]`, `[+Rp50.000]`, `[+Rp100.000]`.

- [ ] **Step 1: Write failing test for HID barcode keystroke stream and quick cash checkout**
- [ ] **Step 2: Run test to verify RED**
- [ ] **Step 3: Implement `BarcodeScannerListener` and quick cash suggestion buttons**
- [ ] **Step 4: Add audio/haptic feedback on successful scan and duplicate tap prevention**
- [ ] **Step 5: Run test to verify GREEN**
- [ ] **Step 6: Commit Task 3**

---

### Task 4: Purchase Workflow, Accounts Payable & Automatic WAC Cost Update

**Files:**
- Create: `lib/features/purchases/data/purchase_repository.dart`
- Create: `lib/features/purchases/data/purchase_service.dart`
- Create: `lib/features/purchases/presentation/purchase_list_screen.dart`
- Create: `lib/features/purchases/presentation/purchase_form_screen.dart`
- Create: `lib/features/purchases/presentation/payable_list_screen.dart`
- Test: `test/features/purchases/purchase_service_wac_test.dart`

**Interfaces:**
- `PurchaseService.finalizePurchase(PurchaseDraft draft)`:
  - Records purchase in `purchases` and `purchase_lines`.
  - Atomically calculates new Weighted Average Cost (WAC) and updates `products.costPriceMinor`.
  - Creates `purchase_in` stock movement in `stock_movements`.
  - Deducts paid amount from Cash/Bank account and registers remaining debt in `payables`.

- [ ] **Step 1: Write failing test for purchase creation, automatic WAC update, and payable recording**
- [ ] **Step 2: Run test to verify RED**
- [ ] **Step 3: Implement `PurchaseRepository` and `PurchaseService`**
- [ ] **Step 4: Build `PurchaseFormScreen`, `PurchaseListScreen`, and `PayableListScreen`**
- [ ] **Step 5: Add Navigation entry in menu "Lainnya -> Pembelian & Hutang"**
- [ ] **Step 6: Run test to verify GREEN**
- [ ] **Step 7: Commit Task 4**

---

### Task 5: Google Drive Encrypted Cloud Backup Adapter

**Files:**
- Create: `lib/features/backup/data/google_drive_backup_service.dart`
- Modify: `lib/features/backup/presentation/data_screen.dart`
- Test: `test/features/backup/google_drive_backup_test.dart`

**Interfaces:**
- `GoogleDriveBackupService`: `Future<void> uploadEncryptedBackup(File nkbFile)`, `Future<List<DriveBackupInfo>> listBackups()`, `Future<File> downloadBackup(String fileId)`
- Maintains AES-256-GCM + PBKDF2 encryption. Google Drive only receives the ciphertext `.nkb`.

- [ ] **Step 1: Write failing test for Google Drive backup upload/download orchestration**
- [ ] **Step 2: Run test to verify RED**
- [ ] **Step 3: Implement `GoogleDriveBackupService` with OAuth2 / Google Sign-In**
- [ ] **Step 4: Add Google Drive upload and restore buttons in `DataScreen` with progress feedback**
- [ ] **Step 5: Run test to verify GREEN**
- [ ] **Step 6: Commit Task 5**

---

### Task 6: Advanced Business Analytics & Profit Reports

**Files:**
- Modify: `lib/features/reports/data/report_repository.dart`
- Modify: `lib/features/reports/presentation/reports_screen.dart`
- Test: `test/features/reports/advanced_analytics_test.dart`

**Interfaces:**
- Laba Kotor vs Laba Bersih (Total Revenue - COGS - Expenses).
- Omzet per Operator/Kasir.
- Fast-moving vs Slow-moving product ranking.

- [ ] **Step 1: Write failing test for profit aggregation and operator breakdown**
- [ ] **Step 2: Run test to verify RED**
- [ ] **Step 3: Implement query aggregations in `ReportRepository`**
- [ ] **Step 4: Update `ReportsScreen` with interactive tabs: Penjualan, Laba/Rugi, Kasir, dan Produk**
- [ ] **Step 5: Run test to verify GREEN**
- [ ] **Step 6: Commit Task 6**

---

### Task 7: Full Verification, Regression Testing & Decision Log Update

**Files:**
- Modify: `docs/AI_DECISION_LOG.md`
- Modify: `docs/IMPLEMENTATION_PLAN.md`

- [ ] **Step 1: Format codebase (`dart format lib test`)**
- [ ] **Step 2: Run `flutter analyze` and ensure 0 issues**
- [ ] **Step 3: Run full `flutter test` and ensure 100% pass**
- [ ] **Step 4: Record decision D-030 in `docs/AI_DECISION_LOG.md`**
- [ ] **Step 5: Commit Task 7**

---

## Verification Plan

### Automated Tests
```bash
# Test individual components
flutter test test/features/printing/receipt_document_renderer_test.dart
flutter test test/features/sales/fast_cashier_barcode_test.dart
flutter test test/features/purchases/purchase_service_wac_test.dart
flutter test test/features/reports/advanced_analytics_test.dart

# Full test suite verification
flutter test

# Static analysis
flutter analyze
```

### Manual Verification on Android Emulator / Device
1. **Receipt Design:** Open an invoice $\rightarrow$ Tap "Cetak Nota" $\rightarrow$ Verify 2-line layout, item count, signature box, and QR code match the *Puri Abadi* format.
2. **Barcode Scanner:** In POS, type barcode keystrokes + Enter $\rightarrow$ verify item auto-added to cart with $+1$.
3. **Quick Cash:** In POS payment sheet, tap `[Rp50.000]` / `[Uang Pas]` $\rightarrow$ verify total and change computed instantly.
4. **Purchase & WAC:** Create a purchase for a product at a new price $\rightarrow$ verify stock increases and product `costPriceMinor` updates to the correct weighted average.
5. **Backup:** Trigger Google Drive backup $\rightarrow$ verify encrypted file `.nkb` uploaded safely.
