# MVP Stabilization Final Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the eleven final-review correctness gaps without weakening NotaKit's integer-money, integer-quantity, immutable-sale, or ledger-first invariants.

**Architecture:** Keep restore validation and replacement inside `BackupService`, with `DataScreen` and onboarding passing the document directory path and only persisting a restored key after replacement succeeds. Keep sales, returns, inventory, pricing, and reports as separate services over the existing Drift schema; add small shared helpers only where the same arithmetic or stock target is required by multiple flows.

**Tech Stack:** Flutter/Dart, Drift/SQLite3MC, Riverpod, `MoneyPolicy`, integer micro-units, AES-256-GCM/PBKDF2 `.nkb` backups, Flutter tests.

**Spec:** `docs/superpowers/specs/2026-08-28-mvp-stabilization-design.md` and the final-review requirements in the user task.

## Global Constraints

- No floating point business math; money remains integer minor units and quantity remains integer micro-units.
- Finalized sales remain immutable; returns are separate documents.
- Inventory movement ledger remains the source of truth; cached stock is updated in the same transaction.
- Restore validates before active replacement and never leaves invalid staging artifacts.
- Existing-device restore probes and reopens with the backup's `dbKeyHex`; onboarding continues to write the key only after successful replacement.
- Preserve parent-product stock behavior for non-variant lines; selected variants use their own stock consistently.

---

### Task 1: Add failing database-state regressions

**Files:**
- Modify: `test/features/backup/backup_service_test.dart`
- Modify: `test/features/sales/sales_return_service_test.dart`
- Modify: `test/features/reports/report_repository_test.dart`
- Modify: `test/features/sales/sales_service_test.dart`
- Create: `test/features/sales/variant_stock_test.dart`

**Interfaces:**
- Tests exercise existing public APIs and describe the required behavior before implementation changes.

- [ ] **Step 1: Add restore regressions**

Cover a restore containing `-wal`/`-shm` artifacts, invalid required schema, invalid KDF algorithm/iterations, and existing-device key replacement. Assert the active file and secure key remain unchanged on every validation failure.

- [ ] **Step 2: Add return arithmetic regressions**

Cover duplicate line requests in one return, repeated partial returns of a `3`-minor-unit line split into `2` and `1`, and assert exactly one return line per source line plus exact totals.

- [ ] **Step 3: Add report regressions**

Cover a credit sale partially returned and assert due/new-receivable, `salesSummary`, `dailyTotals`, and CSV-facing daily values all reflect the return state.

- [ ] **Step 4: Add checkout/unit/variant regressions**

Cover customer pricing changing the payment total after cart creation, non-integral conversion rejection, exact `conversionFactorMicro` persistence, and variant stock decrement/return/movement isolation from the parent product.

- [ ] **Step 5: Run the new tests and confirm RED**

Run:
```powershell
flutter test test/features/backup/backup_service_test.dart test/features/sales/sales_return_service_test.dart test/features/reports/report_repository_test.dart test/features/sales/sales_service_test.dart test/features/sales/variant_stock_test.dart
```
Expected: the newly added assertions fail for the currently observed behaviors.

### Task 2: Harden restore paths and backup validation

**Files:**
- Modify: `lib/features/backup/presentation/data_screen.dart`
- Modify: `lib/features/onboarding/onboarding_screen.dart`
- Modify: `lib/features/backup/data/backup_crypto.dart`
- Modify: `lib/features/backup/data/backup_service.dart`
- Modify: `lib/features/backup/data/nkb_container.dart`
- Modify: `lib/features/security/providers.dart`

**Interfaces:**
- `BackupService.inspect` rejects malformed crypto parameters before KDF work and returns `RestorePreview.dbKeyHex`.
- `BackupService.applyRestore` validates the staged database against an explicit required NotaKit table set, cleans staging on every failure, handles sidecars, and keeps the previous database recoverable until replacement validation/reopen succeeds.
- Existing-device callers pass `preview.dbKeyHex` to probe/apply and persist that key only after replacement succeeds; onboarding keeps its post-restore PIN flow.

- [ ] **Step 1: Implement manifest/KDF validation**

Validate format/cipher/KDF algorithm, integer iteration bounds, exact salt/nonce lengths, and required manifest fields before deriving a key. Preserve wrong-password classification only for valid crypto parameters.

- [ ] **Step 2: Implement explicit schema validation**

Replace table-count checks with the complete required production table-name set and fail with `BackupFormatException` when any required table is missing.

- [ ] **Step 3: Implement staging cleanup and sidecar management**

Delete staging and its `-wal`/`-shm` companions in every validation/error path; checkpoint/close probe data before swap; move the active database and sidecars together where present.

- [ ] **Step 4: Implement recoverable replacement and post-swap validation**

Keep the previous database files until the staged target can be opened and integrity-checked using `preview.dbKeyHex`. Roll back target and sidecars if replacement or reopen validation fails, then clean all temporary files.

- [ ] **Step 5: Wire document paths and key ordering**

Use `(await getDocsDir()).path` in `DataScreen`; pass `preview.dbKeyHex` for existing-device restore; write `nk.db.key` only after `applyRestore` succeeds. Preserve onboarding's backup-key write after successful replacement and before reopening.

- [ ] **Step 6: Run backup/onboarding regressions and confirm GREEN**

Run:
```powershell
flutter test test/features/backup/backup_service_test.dart test/features/security/onboarding_flow_test.dart
```

### Task 3: Correct returns, variant inventory, and exact unit conversion

**Files:**
- Modify: `lib/features/sales/data/sales_return_service.dart`
- Modify: `lib/features/sales/data/sales_service.dart`
- Modify: `lib/features/inventory/data/inventory_service.dart`
- Modify: `lib/features/sales/controllers/sales_providers.dart`
- Modify: `lib/features/products/data/product_repository.dart`

**Interfaces:**
- Return requests aggregate by `saleLineId` before availability validation and allocation.
- A return line's amount uses cumulative proportional allocation so repeated partial returns consume every original minor unit exactly once.
- Selected variant stock is read/written on `ProductVariants` and movement rows; non-variant lines continue to use `Products`.
- Conversion validation rejects a sold quantity whose base-unit product is not integral and persists the original factor exactly.

- [ ] **Step 1: Implement duplicate aggregation and residual allocation**

Normalize one request into one quantity per source line, calculate amount as total-line allocation minus prior allocations, and store exact return rows/totals.

- [ ] **Step 2: Implement shared variant stock target handling**

For checkout, movement, and return, resolve either the selected variant row or the parent product row, check available stock before mutation, and update only that target's cached stock while retaining the parent product id in ledger rows.

- [ ] **Step 3: Preserve exact conversion factors**

Compute `qtyBaseMicro` only when `(qtyMicro * conversionFactorMicro) % quantityScale == 0`; otherwise throw `Failure.invalidQuantity`. Persist `conversionFactorMicro` directly instead of reconstructing it from rounded quantities.

- [ ] **Step 4: Run sales/inventory regressions and confirm GREEN**

Run:
```powershell
flutter test test/features/sales/sales_service_test.dart test/features/sales/sales_return_service_test.dart test/features/sales/variant_stock_test.dart
```

### Task 4: Make reports and checkout UI state-aware

**Files:**
- Modify: `lib/features/reports/data/report_repository.dart`
- Modify: `lib/features/sales/presentation/new_sale_screen.dart`
- Modify: `lib/features/sales/controllers/sales_providers.dart`
- Modify: `test/features/reports/report_repository_test.dart`
- Modify: `test/features/sales/sales_service_test.dart`

**Interfaces:**
- `dailyTotals` returns net sale totals after returns for every requested day; CSV export consumes that same result without a second interpretation.
- Report due/new-receivable values reflect current return-adjusted receivable state.
- Checkout resolves customer-dependent pricing before showing the payment total and submits the same resolved line values, or prevents stale customer changes.

- [ ] **Step 1: Make return accounting consistent by state**

Define the report rule in code: finalized sales contribute positive totals and returns contribute negative totals in their report day; due/new receivable uses return-adjusted remaining amounts for sales in the requested period. Apply the same net values to daily totals and CSV.

- [ ] **Step 2: Add a service preview/resolution path for checkout**

Expose a lightweight `previewCheckout` result or equivalent resolver reuse that accepts the selected customer and returns resolved line prices and grand total without mutation. Use it for the payment sheet and submit the same resolved context to `checkout`.

- [ ] **Step 3: Update the payment UI**

Do not initialize or display the cart subtotal after a customer-dependent price can apply; refresh the displayed total on customer change and parse payment against the resolved total.

- [ ] **Step 4: Run report and widget-focused tests and confirm GREEN**

Run:
```powershell
flutter test test/features/reports/report_repository_test.dart test/features/sales/sales_service_test.dart test/features/security/onboarding_flow_test.dart
```

### Task 5: Format, analyze, run full verification, report, and commit

**Files:**
- Create: `.superpowers/sdd/mvp-stabilization/final-fix-report.md`

**Interfaces:**
- The report records exact changes, commands/results, and open concerns without claiming unrun checks.

- [ ] **Step 1: Format changed Dart files**

Run:
```powershell
dart format lib test
```

- [ ] **Step 2: Run required verification**

Run:
```powershell
flutter analyze
flutter test test/features/backup test/features/sales test/features/reports test/database
flutter test
```

- [ ] **Step 3: Write the final fix report**

Write `final-fix-report.md` with sections for implemented changes, focused tests, full tests, open concerns, and the exact commit id after committing.

- [ ] **Step 4: Commit the complete fix**

```powershell
git add lib test docs/superpowers/plans/2026-08-28-mvp-stabilization-final-fixes.md .superpowers/sdd/mvp-stabilization/final-fix-report.md
git commit -m "fix: close MVP stabilization correctness gaps" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
