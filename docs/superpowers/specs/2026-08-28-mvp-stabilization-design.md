# NotaKit MVP Stabilization Design

**Date:** 2026-08-28
**Status:** Approved for implementation

## Goal

Close the remaining correctness and release-hardening gaps without entering
Phase 2 or weakening NotaKit's existing local-first business rules.

## Decisions

### 1. Sale reversal

Finalized sales remain immutable. A reversal is represented by a dedicated
return/refund document linked to the original sale. The reversal is atomic and
must update stock movements, payment/refund records, ledger entries, account
balances, receivable allocations, and audit logs together.

Until the reversal document exists, `voidSale` must reject sales that have
payment or receivable side effects. This is safer than a partial financial
void.

### 2. Pricing and quantity

Checkout resolves the selected product unit/variant and price before the sale
transaction commits. Sale lines persist the resolved unit, conversion factor,
unit price, and product/variant snapshots. Base quantity is calculated with
integer micro-units only. Existing `MoneyPolicy` remains the sole money
rounding authority.

### 3. Database and backup

Every schema change increments `schemaVersion` and has a production Drift
migration plus migration tests from the previous schema. Backup metadata comes
from runtime database/app configuration. Restore validates the staged database
using the same encryption and pragma setup as production, closes the active
database deterministically, and uses recoverable file replacement.

### 4. UX and release verification

Credit checkout requires explicit customer selection. Restore requires preview
and destructive confirmation. Critical loading, empty, and error states are
made explicit. Android integration tests cover the critical recovery path;
crash injection remains a separate hardening test where the platform permits it.

## Scope boundaries

Included: return/refund reversal, pricing/unit/variant checkout wiring, stock
valuation precision, migration harness, backup metadata and restore hardening,
critical UX states, performance query cleanup, documentation, and regression
tests.

Excluded: restaurant mode, marketplace adapters, cloud sync, advanced
accounting, purchase workflow expansion, and printer transport adapters.

## Acceptance criteria

- No committed sale can create an unowned receivable.
- Every reversal preserves stock, payment, receivable, ledger, account, and
  audit invariants atomically.
- Historical sale snapshots are unaffected by later master-data changes.
- Fractional stock valuation preserves micro-unit precision.
- A database from the immediately previous schema migrates successfully.
- Malformed or wrong-password backups never modify the active database.
- `flutter analyze`, `flutter test`, relevant Android integration tests, and
  `flutter build apk --debug` pass on the verification environment.
- Documentation distinguishes `PASS VERIFIED NOW` from historical execution.
