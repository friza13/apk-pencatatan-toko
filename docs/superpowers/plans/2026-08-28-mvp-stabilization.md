# NotaKit MVP Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close remaining MVP correctness and release-hardening gaps before Phase 2.

**Architecture:** Keep Flutter/Riverpod/Drift clean architecture. Add reversal behavior as a domain/application service around existing sales, payment, receivable, inventory, ledger, and audit tables; do not mutate finalized sale history. Wire existing pricing and unit models into checkout, and harden database/backup boundaries with explicit migrations and deterministic lifecycle.

**Tech Stack:** Flutter/Dart, Riverpod, Drift/SQLite3MC, `MoneyPolicy`, integer micro-unit quantity, AES-256-GCM/PBKDF2 `.nkb` backup, Flutter widget/integration tests.

**Spec:** `docs/superpowers/specs/2026-08-28-mvp-stabilization-design.md`

## Global Constraints

- Local-first, offline-first, single-owner; no server dependency.
- Money uses integer minor units and `MoneyPolicy`; no floating-point business calculations.
- Quantity uses integer micro-units with `quantityScale = 1000000`.
- Timestamps are stored in UTC.
- Inventory movement ledger is the source of truth; cached stock is derived.
- Finalized sales are immutable and changed only through return/refund documents.
- Every schema change increments `schemaVersion` and includes a Drift migration.
- Backup restore validates before touching the active database.
- Do not start Phase 2 or add marketplace/restaurant/cloud-sync scope.
- Every logical milestone requires targeted tests, analyzer, and a local Git checkpoint; never push.

---

### Task 1: Establish recovery branch checkpoint and focused test fixtures

**Files:**
- Create: `test/helpers/business_fixture.dart`
- Modify: `test/features/sales/sales_service_test.dart`
- Modify: `test/features/backup/backup_service_test.dart`
- Modify: `test/features/security/onboarding_flow_test.dart`
- Modify: `docs/AI_AUDIT.md`

**Interfaces:**
- Produces reusable fixture helpers for business, account, product, customer,
  and stock setup.
- Produces named regression tests that later tasks extend without changing
  business semantics.

- [ ] **Step 1: Create the pre-change checkpoint**

Run:
```powershell
git status --short
git add -A
git commit -m "chore: checkpoint before MVP stabilization" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 2: Extract only duplicated test setup into a fixture**

Create a fixture exposing:
```dart
class BusinessFixture {
  BusinessFixture(this.db);
  final AppDatabase db;
  late int businessId;
  late int accountId;
  late int productId;
  late int customerId;
  Future<void> seed();
  Future<int> stockOf(int productId);
}
```
Keep production code unchanged.

- [ ] **Step 3: Run the existing focused suites**

Run:
```powershell
flutter test test/features/sales/sales_service_test.dart test/features/backup/backup_service_test.dart test/features/security/onboarding_flow_test.dart
```
Expected: PASS before new behavior changes.

- [ ] **Step 4: Commit the fixture-only milestone**

```powershell
git add test/helpers test/features docs/AI_AUDIT.md
git commit -m "test: centralize MVP recovery fixtures" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Add the return/refund data model and migration

**Files:**
- Modify: `lib/database/tables/payment_tables.dart`
- Modify: `lib/database/tables/sales_tables.dart`
- Modify: `lib/database/app_database.dart`
- Modify: `lib/database/app_database.g.dart` (generated)
- Create: `test/database/migration_v1_test.dart`

**Interfaces:**
- Produces a return header and return-line representation linked to the
  original sale.
- Produces a refund payment representation linked to the reversal document.
- Produces schema version 2 and an upgrade path from schema version 1.

- [ ] **Step 1: Write failing schema and migration tests**

Test that a v1 database upgrades to v2 and that the new tables contain
foreign-key links to the original sale and its lines. Assert that existing v1
sales and payments remain readable.

- [ ] **Step 2: Run the migration test to verify RED**

```powershell
flutter test test/database/migration_v1_test.dart
```
Expected: FAIL because schema version 2 and migration tables do not exist.

- [ ] **Step 3: Add minimal tables and constraints**

Add `SalesReturns` and `SalesReturnLines` fields for original sale, business,
reason, status, total, refund total, quantity, base quantity, snapshots,
created/posted timestamps, and audit linkage. Add a refund payment purpose and
optional return id. Preserve positive payment amounts and foreign keys.

- [ ] **Step 4: Implement `onUpgrade` from v1 to v2**

Use Drift migration statements to create only the new columns/tables and
indexes. Do not rebuild unrelated tables or silently rewrite historical data.

- [ ] **Step 5: Regenerate Drift code and rerun migration tests**

```powershell
dart run build_runner build --delete-conflicting-outputs
flutter test test/database/migration_v1_test.dart
```
Expected: PASS.

- [ ] **Step 6: Commit the schema milestone**

```powershell
git add lib/database test/database
git commit -m "feat: add return refund schema migration" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Implement atomic return/refund reversal service

**Files:**
- Create: `lib/features/sales/data/sales_return_service.dart`
- Modify: `lib/features/sales/data/sales_service.dart`
- Modify: `lib/features/receivables/data/receivable_service.dart`
- Modify: `lib/core/error/failures.dart`
- Create: `test/features/sales/sales_return_service_test.dart`

**Interfaces:**
- Produces:
  `Future<SalesReturnOutput> createReturn(SalesReturnInput input)`.
- Input includes original sale id, line quantities in micro-units, refund
  account, refund method, and reason.
- The operation is one Drift transaction and is idempotent for a supplied
  client/reference id.

- [ ] **Step 1: Write failing invariant tests**

Cover:
```dart
test('full cash return restores stock and reverses account balance', ...);
test('partial return reverses only selected quantity', ...);
test('credit return reduces receivable without creating cash', ...);
test('return failure rolls back stock, payment, ledger, receivable, and audit', ...);
test('return cannot exceed remaining sale quantity', ...);
```
Each test must inspect database rows and cached balances before and after.

- [ ] **Step 2: Run the tests to verify RED**

```powershell
flutter test test/features/sales/sales_return_service_test.dart
```
Expected: FAIL because the service and reversal API do not exist.

- [ ] **Step 3: Implement validation before mutation**

Load the original sale and lines, reject voided/non-finalized sales, validate
positive requested quantities, validate remaining returnable quantity, and
calculate refund using original line snapshots and `MoneyPolicy`.

- [ ] **Step 4: Implement stock reversal and return lines atomically**

Insert a return header and lines, insert positive stock movements with the
original cost snapshot, and update cached stock in the same transaction.

- [ ] **Step 5: Implement financial reversal atomically**

For paid amounts, insert an outbound refund payment, paired reversal ledger
entry, and decrement the refund account balance. For unpaid credit amounts,
reduce the linked receivable and record the allocation/reversal without
inventing a cash movement. Reject mixed unsupported states explicitly.

- [ ] **Step 6: Add audit events and idempotency**

Write `sale.returned` with original sale id, return id, quantities, and amount.
Use a unique client/reference key so retrying the same request cannot duplicate
stock or money effects.

- [ ] **Step 7: Update void behavior**

Keep `voidSale` as a safe operation only for finalized sales with no payment,
receivable, or return side effects. Route paid/credit corrections to the return
service rather than silently mutating financial state.

- [ ] **Step 8: Run sales suites and commit**

```powershell
flutter test test/features/sales/sales_return_service_test.dart test/features/sales/sales_service_test.dart test/features/finance/p7_services_test.dart
git add lib test
git commit -m "feat: add atomic sale return and refund reversal" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Wire pricing, units, and variants into checkout

**Files:**
- Modify: `lib/features/sales/data/sales_service.dart`
- Modify: `lib/features/sales/controllers/sales_providers.dart`
- Modify: `lib/features/sales/presentation/new_sale_screen.dart`
- Modify: `lib/features/pricing/**`
- Create: `test/features/sales/checkout_pricing_conversion_test.dart`

**Interfaces:**
- Checkout receives a resolved `SaleLineInput` with selected unit/variant and
  uses a single resolver for price and base quantity.
- Sale line snapshots include selected unit, variant, conversion factor, price,
  and base quantity.

- [ ] **Step 1: Write failing checkout tests**

Cover:
```dart
test('selling a converted unit stores base quantity correctly', ...);
test('variant price overrides product price and is snapshotted', ...);
test('customer tier and quantity break resolve through PricingEngine', ...);
test('later master-data edits do not change historical sale lines', ...);
```

- [ ] **Step 2: Run the focused tests to verify RED**

```powershell
flutter test test/features/sales/checkout_pricing_conversion_test.dart
```

- [ ] **Step 3: Add a typed checkout resolution result**

Define a resolver result containing unit id/code, variant id, conversion factor,
unit price, and base quantity. Use integer multiplication/division with explicit
rounding rules; reject overflow or non-integral base quantities rather than
silently truncating.

- [ ] **Step 4: Connect the cart and UI to the resolver**

Make cart lines carry selected unit/variant/customer context. Remove direct
unchecked price injection from the UI path; retain service-side validation as
the authority.

- [ ] **Step 5: Persist and test snapshots**

Write the resolved values to sale lines and verify master data changes after
checkout do not affect reports or returns.

- [ ] **Step 6: Commit the pricing milestone**

```powershell
git add lib test
git commit -m "feat: connect pricing and unit conversion to checkout" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Fix quantity-precise stock valuation and report aggregation

**Files:**
- Modify: `lib/features/reports/data/report_repository.dart`
- Create: `test/features/reports/stock_valuation_precision_test.dart`
- Modify: `test/features/reports/report_repository_test.dart`

**Interfaces:**
- `stockValuationMinor` returns rounded integer minor units from micro quantity
  without discarding fractions.
- `dailyTotals` uses one bounded aggregation query for the requested period.

- [ ] **Step 1: Write failing precision and aggregation tests**

Assert that 0.5 units at Rp8,000 values to Rp4,000 and that a 30-day query
returns the same totals as per-day reference data.

- [ ] **Step 2: Run tests to verify RED**

```powershell
flutter test test/features/reports/stock_valuation_precision_test.dart
```

- [ ] **Step 3: Implement integer-safe valuation**

Calculate `(stockQuantityMicro * costPriceMinor) ~/ quantityScale` with a
documented non-negative rounding policy and guard multiplication overflow.

- [ ] **Step 4: Replace per-day query loop with bounded aggregation**

Fetch the period rows once, group by business-local day in Dart using the
existing `BusinessClock`, and preserve empty days in the returned list.

- [ ] **Step 5: Run report suites and commit**

```powershell
flutter test test/features/reports/stock_valuation_precision_test.dart test/features/reports/report_repository_test.dart
git add lib test
git commit -m "fix: preserve fractional stock valuation precision" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Complete production migration and backup metadata hardening

**Files:**
- Modify: `lib/database/app_database.dart`
- Modify: `lib/features/backup/data/backup_service.dart`
- Modify: `lib/features/backup/presentation/data_screen.dart`
- Create: `lib/core/app/app_metadata.dart`
- Create: `test/features/backup/backup_metadata_test.dart`
- Modify: `test/database/app_database_test.dart`

**Interfaces:**
- `AppMetadata` exposes runtime app version and database schema version.
- Backup UI/service consumes `AppMetadata`; no hard-coded schema/app values.
- Staging uses the same encrypted executor setup as production.

- [ ] **Step 1: Write failing metadata and migration tests**

Assert backup manifest uses `AppDatabase.schemaVersion` and package runtime
version, and that staging runs the same key/foreign-key/WAL setup.

- [ ] **Step 2: Run tests to verify RED**

```powershell
flutter test test/features/backup/backup_metadata_test.dart test/database/app_database_test.dart
```

- [ ] **Step 3: Add `AppMetadata`**

Read package version from `package_info_plus` or the repository's existing
metadata source; expose a test override. Keep schema version sourced from the
database instance.

- [ ] **Step 4: Centralize encrypted executor setup**

Reuse one setup function for production and restore probe, including escaped
key, foreign keys, WAL, and forced first query. Never log passphrases.

- [ ] **Step 5: Wire DataScreen and backup creation**

Remove hard-coded `schemaVersion: 1` and `appVersion: '1.0.0-dev'`; pass runtime
values through the existing provider/service boundary.

- [ ] **Step 6: Run backup and migration suites and commit**

```powershell
flutter test test/features/backup test/database
git add lib test
git commit -m "fix: harden production migration and backup metadata" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Finish restore UX and critical loading/error states

**Files:**
- Modify: `lib/features/backup/presentation/data_screen.dart`
- Modify: `lib/features/onboarding/onboarding_screen.dart`
- Modify: `lib/features/sales/presentation/new_sale_screen.dart`
- Modify: `lib/features/app_router.dart` or the existing settings route file
- Create/modify: relevant widget tests

**Interfaces:**
- Restore always presents preview, then a separate destructive confirmation.
- Credit/partial checkout presents customer selection and blocks submit without
  customer.
- Async failures remain visible with typed user-facing messages.

- [ ] **Step 1: Write failing widget tests**

Cover preview confirmation, cancel preserving the active database, customer
selection requirement, and visible loading/error states.

- [ ] **Step 2: Run widget tests to verify RED**

```powershell
flutter test test/features/backup test/features/sales test/app
```

- [ ] **Step 3: Implement restore confirmation and customer selection**

Do not start `applyRestore` until the user confirms the preview. Disable repeat
actions while busy and show the existing error state on failure.

- [ ] **Step 4: Implement settings route only if an existing route contract exists**

Use the existing router and screen patterns; do not introduce unrelated settings
features. If no route contract exists, document it as deferred instead of using
a fake snackbar.

- [ ] **Step 5: Run widget suites and commit**

```powershell
flutter test test/features/backup test/features/sales test/app
git add lib test
git commit -m "fix: complete critical MVP recovery UX" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 8: Re-audit, Android verification, and release status

**Files:**
- Modify: `docs/AI_AUDIT.md`
- Modify: `docs/AI_DECISION_LOG.md`
- Modify: `docs/IMPLEMENTATION_PLAN.md`
- Modify: `integration_test/e2e_recovery_test.dart`
- Create: `docs/RECOVERY_NOTES.md`

**Interfaces:**
- Documentation reports each acceptance criterion as `PASS VERIFIED NOW`,
  `PASS FROM PREVIOUS EXECUTION LOG`, `OPEN`, or `DEFERRED`.

- [ ] **Step 1: Run the complete verification matrix**

```powershell
flutter analyze
flutter test
flutter test integration_test\e2e_recovery_test.dart -d emulator-5554
flutter build apk --debug
```

- [ ] **Step 2: Exercise critical flows on the emulator**

Verify onboarding, normal sale, partial payment, credit sale, return/refund,
stock adjustment, receivable settlement, cash/bank movement, backup, restore,
wrong password, corrupt backup, app restart, and database recovery.

- [ ] **Step 3: Re-audit source, schema, tests, docs, and Git**

Confirm each changed invariant from the design document has a test that reads
database state before and after the operation. Record limitations explicitly.

- [ ] **Step 4: Update status documentation**

Remove stale claims, record exact commands and outcomes, and keep Phase 2
deferred until all acceptance criteria are either verified or explicitly
approved as deferred.

- [ ] **Step 5: Commit the final stabilization milestone**

```powershell
git add docs integration_test
git commit -m "docs: record MVP stabilization verification" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
