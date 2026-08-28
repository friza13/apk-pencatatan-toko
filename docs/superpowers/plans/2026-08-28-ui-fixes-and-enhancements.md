# UI Fixes & Enhancements (Paket A + Paket B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close UI bugs, runtime risks, dead code, missing Store Settings screen, and add Variant/Unit conversion picker to POS Cart.

**Architecture:** 
- Standard Clean Architecture & Riverpod providers.
- Maintain integer minor money (`MoneyPolicy`) and integer micro-unit quantity (`quantityScale = 1000000`).
- Use `AppDatabase` via Riverpod providers to update store settings (`Businesses` table).
- Enhance `CartLine` and `NewSaleScreen` to support `variantId` and `unitId` resolving to `SalesService.checkout` & `previewTotal`.

**Tech Stack:** Flutter / Dart, Riverpod, Drift / SQLite3MC, `intl` date formatting, GoRouter.

**Spec / Requirements:**
- PRD §Q (Store Settings), SRS §FR-STORE-001 (Store Profile), SRS §FR-PRINT-001 (Receipt formatting), SRS §FR-PROD-002 / FR-PROD-003 (Variants & Unit Conversion).

---

## Global Constraints

- No floating point math for currency or quantity calculations.
- Money remains integer minor units and quantity remains integer micro-units.
- Single-owner local-first architecture; do not introduce external cloud/server dependencies.
- Zero issues in `flutter analyze` and 100% pass in `flutter test`.

---

### Task 1: Fix Receipt Print Quantity Formatting & Return Decimal Parsing (Paket A)

**Files:**
- Modify: `lib/features/printing/presentation/print_sheet.dart`
- Modify: `lib/features/sales/presentation/sale_detail_screen.dart`
- Create: `test/features/printing/print_sheet_test.dart`

**Interfaces:**
- `PrintSheet` uses `microToDecimalString(l.qtyBaseMicro)` for receipt lines.
- `SaleDetailScreen._returnDialog` uses `toMicro(value)` to handle decimal quantities (e.g. `0.5`).

- [x] **Step 1: Write widget and unit tests for receipt printing and decimal return parsing**

Write tests asserting:
1. `PrintSheet` formats `qtyBaseMicro = 1000000` as `"1"` and not `"1000000"`.
2. Decimal return parsing parses `"0.5"` to `500000` micro-units.

- [x] **Step 2: Run tests to verify failure**

Run:
```powershell
flutter test test/features/printing/print_sheet_test.dart
```

- [x] **Step 3: Fix `print_sheet.dart` and `sale_detail_screen.dart`**

In `lib/features/printing/presentation/print_sheet.dart`:
Replace:
```dart
qty: l.qtyBaseMicro.toString(),
```
with:
```dart
qty: microToDecimalString(l.qtyBaseMicro),
```

In `lib/features/sales/presentation/sale_detail_screen.dart`:
Replace:
```dart
onChanged: (value) => quantities[line.id] = (int.tryParse(value) ?? 0) * quantityScale,
```
with:
```dart
onChanged: (value) {
  try {
    quantities[line.id] = toMicro(value.trim());
  } catch (_) {
    quantities[line.id] = 0;
  }
},
```

- [x] **Step 4: Run tests to verify PASS**

Run:
```powershell
flutter test test/features/printing/print_sheet_test.dart
```

- [x] **Step 5: Commit Task 1**

```powershell
git add lib/features/printing lib/features/sales test/features/printing
git commit -m "fix: format receipt quantity and handle decimal return quantities"
```

---

### Task 2: Initialize Intl Date Formatting and Remove Dead Code (Paket A)

**Files:**
- Modify: `lib/main.dart`
- Delete: `lib/features/products/products_screen.dart`
- Create: `test/app/intl_initialization_test.dart`

**Interfaces:**
- `main()` is `async`, calls `WidgetsFlutterBinding.ensureInitialized()` and `await initializeDateFormatting('id_ID', null)` before `runApp`.
- Dead placeholder file `lib/features/products/products_screen.dart` is removed.

- [x] **Step 1: Write test for date formatting with 'id_ID' locale**

Verify `DateFormat('dd MMM HH:mm', 'id_ID').format(DateTime.now())` does not throw an uninitialized locale exception.

- [x] **Step 2: Implement `initializeDateFormatting` in `main.dart` and delete dead file**

Update `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/auth_gate.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const ProviderScope(child: NotaKitApp()));
}
```
Remove `lib/features/products/products_screen.dart`.

- [x] **Step 3: Run tests and verify PASS**

Run:
```powershell
flutter test test/app/intl_initialization_test.dart
```

- [x] **Step 4: Commit Task 2**

```powershell
git rm lib/features/products/products_screen.dart
git add lib/main.dart test/app/intl_initialization_test.dart
git commit -m "fix: initialize id_ID date formatting and remove dead placeholder"
```

---

### Task 3: Store Profile / Settings UI & Route (Paket B)

**Files:**
- Create: `lib/features/settings/presentation/store_profile_screen.dart`
- Modify: `lib/features/settings/more_menu_screen.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `test/features/settings/store_profile_screen_test.dart`

**Interfaces:**
- `StoreProfileScreen` loads `currentBusinessProvider`, allows editing `name`, `phone`, `address`, and `footerNote`.
- Saves to `db.businesses` and invalidates `currentBusinessProvider`.
- Router maps `/more/settings` to `StoreProfileScreen`.
- `MoreMenuScreen` navigates to `/more/settings` on clicking 'Pengaturan'.

- [x] **Step 1: Write widget test for StoreProfileScreen**

Test loading store details, editing fields, saving changes, and verifying the updated values.

- [x] **Step 2: Run test to verify RED**

Run:
```powershell
flutter test test/features/settings/store_profile_screen_test.dart
```

- [x] **Step 3: Implement StoreProfileScreen, wire Route and Menu**

Implement `StoreProfileScreen` with `TextEditingController` for store name, phone, address, and footer note.
Wire route in `app_router.dart` and `more_menu_screen.dart`.

- [x] **Step 4: Run test to verify GREEN**

Run:
```powershell
flutter test test/features/settings/store_profile_screen_test.dart
```

- [x] **Step 5: Commit Task 3**

```powershell
git add lib/features/settings lib/app/router test/features/settings
git commit -m "feat: add store profile settings screen and wire navigation"
```

---

### Task 4: Variant & Unit Conversion Selection in POS Cart (Paket B)

**Files:**
- Modify: `lib/features/sales/controllers/sales_providers.dart`
- Modify: `lib/features/sales/presentation/new_sale_screen.dart`
- Create: `test/features/sales/pos_variant_unit_cart_test.dart`

**Interfaces:**
- `CartLine` carries `variantId`, `variantName`, `unitId`, `unitName`, `conversionFactorMicro`.
- `CartController.addVariantOrUnit(...)` adds an item with specific variant/unit details.
- `NewSaleScreen` checks if product has variants (`detail.variants`) or alternate units (`detail.units`). If yes, displays a selection bottom sheet before adding to cart.
- `NewSaleScreen._checkout` passes `variantId` and `unitId` in `SaleLineInput` to `SalesService.checkout` and `SalesService.previewTotal`.

- [x] **Step 1: Write failing tests for variant and unit selection in Cart & Checkout**

Test:
1. Adding a variant item to cart with variant price snapshot.
2. Adding a converted unit item to cart with unit conversion factor.
3. Checking out variant and unit lines correctly decrements variant/parent stock and records line snapshots.

- [x] **Step 2: Run test to verify RED**

Run:
```powershell
flutter test test/features/sales/pos_variant_unit_cart_test.dart
```

- [x] **Step 3: Update `CartLine`, `CartController`, and `NewSaleScreen`**

1. Extend `CartLine`:
```dart
class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    required this.qtyMicro,
    required this.unitPriceMinor,
    this.variantId,
    this.variantName,
    this.unitId,
    this.unitName,
    this.conversionFactorMicro = quantityScale,
    this.tracked = true,
    this.currentStockMicro = 0,
  });
  ...
}
```
2. In `NewSaleScreen`, when user taps a product from search:
   - Query product details `repo.detail(p.id)`.
   - If variants or extra units exist, show a clean BottomSheet with options (e.g. Pilih Varian / Satuan).
   - Add the selected option to cart.
3. Update `_checkout()` in `NewSaleScreen` to map `l.variantId` and `l.unitId` to `SaleLineInput`.

- [x] **Step 4: Run test to verify GREEN**

Run:
```powershell
flutter test test/features/sales/pos_variant_unit_cart_test.dart test/features/sales/checkout_pricing_conversion_test.dart
```

- [x] **Step 5: Commit Task 4**

```powershell
git add lib/features/sales test/features/sales
git commit -m "feat: add variant and unit selection to POS cart and checkout"
```

---

### Task 5: Formatting, Analysis, Full Test Verification, and Documentation

**Files:**
- Modify: `docs/AI_DECISION_LOG.md`
- Modify: `docs/IMPLEMENTATION_PLAN.md`

- [x] **Step 1: Format Dart code**

Run:
```powershell
dart format lib test
```

- [x] **Step 2: Run static analyzer**

Run:
```powershell
flutter analyze
```
Expected: 0 issues.

- [x] **Step 3: Run full test suite**

Run:
```powershell
flutter test
```
Expected: All tests pass.

- [x] **Step 4: Update Documentation**

Record new decision (D-028: Store profile UI and POS variant/unit picker) in `docs/AI_DECISION_LOG.md`.

- [x] **Step 5: Final commit**

```powershell
git add docs/
git commit -m "docs: record UI fixes and POS variant/unit enhancement"
```
