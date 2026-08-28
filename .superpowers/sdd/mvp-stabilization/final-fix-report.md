# MVP Stabilization Final Fix Report

## Changes

- Corrected DataScreen backup/restore paths to use `Directory.path`; existing-device restore now probes and applies with `preview.dbKeyHex`, persists the restored key only after a successful replacement, and preserves onboarding key flow.
- Hardened backup validation with explicit manifest crypto checks, bounded PBKDF2 iterations, salt/nonce validation, explicit required NotaKit schema validation, WAL/SHM staging cleanup, recoverable previous-file swap, post-swap reopen validation, and rollback handling.
- Aggregated duplicate return lines and changed repeated partial-return allocation to cumulative integer allocation so residual minor units are preserved. Return stock movements and cached stock now target the selected variant where applicable; voided variant sales and inventory movements follow the same rule.
- Added exact unit-conversion validation and persistence of the original `conversionFactorMicro`; non-integral base quantities are rejected.
- Made sales summaries and daily totals return-aware, state-aware, and refund-aware; CSV output consumes the corrected daily totals.
- Added a shared non-mutating `SalesService.previewTotal` path and wired the payment sheet to resolve customer pricing before displaying/defaulting the payment total.

## Regression coverage

- Backup replacement preserves the active database and cleans restore staging after incomplete-schema validation failure.
- Duplicate and repeated partial returns inspect persisted return lines, amounts, stock, payments, and receivables.
- Report tests cover return-adjusted totals, profit, due amounts, and daily totals.
- Sales tests cover customer pricing preview, exact conversion persistence, and rejection of non-integral conversion.
- Variant tests inspect checkout, return, and movement isolation between parent and variant stock.

## Verification

- `dart format lib test`
- `flutter analyze` — passed with no issues.
- Focused regressions — passed:
  `flutter test test/features/backup/backup_service_test.dart test/features/sales/sales_service_test.dart test/features/sales/sales_return_service_test.dart test/features/sales/variant_stock_test.dart test/features/reports/report_repository_test.dart`
- Full suite — passed: `flutter test`

## Open concerns

- Drift emits its existing multiple-`AppDatabase` debug warning while a restore probe is opened beside the test database; the probe is explicitly closed and the warning does not affect test results. A larger executor/lifecycle refactor was intentionally avoided in this stabilization pass.