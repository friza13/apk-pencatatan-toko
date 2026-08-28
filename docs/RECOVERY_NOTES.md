# NotaKit Recovery Notes

**Verification date:** 2026-08-28  
**Branch:** `mvp-stabilization`

## Verified now

- `flutter analyze` passes with no issues.
- Full Flutter test suite passes: 158 tests.
- Debug APK builds successfully.
- Android recovery integration test passes on `emulator-5554` (Android 15
  API 35).
- Backup preview is validated before the active database is closed.
- Wrong password, checksum mismatch, malformed payload, and incomplete
  staging database are rejected without replacing the active database.
- Backup manifests use runtime package version and the active database schema
  version.

## Recovery behavior

Restore follows: inspect and decrypt -> show preview -> destructive
confirmation -> close active database -> stage and integrity-check -> atomic
replacement with rollback on failure.

Return/refund application logic is atomic and covered by database-state tests.
The sales detail screen now exposes a dedicated return flow with quantity and
reason validation, and refreshes sale, product, and sales-list state after a
successful return.

## Open or deferred

- Production schema remains version 1 because the existing return tables were
  already present; no migration was invented or applied unnecessarily.
- Return request idempotency and multiple-payment refund allocation require a
  future schema/business-rule decision and remain deferred.
- Full emulator walkthrough for the return UI remains a release verification
  follow-up and is recorded as **NOT VERIFIED**, not as a failed MVP bug.
- Phase 2 remains a separate future scope and is not started automatically.

## Scope rule

The items above are **DEFERRED**, not active MVP bugs. They must not be
implemented automatically or treated as MVP blockers without explicit
instruction. Any future implementation must preserve backward compatibility,
atomic domain effects, regression coverage, and historical transaction
immutability.
