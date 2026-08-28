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
The current MVP does not expose a dedicated return button in the sales detail
screen; this remains a deliberate UI follow-up, not an unverified claim that
the feature is fully user-accessible.

## Open or deferred

- Production schema remains version 1 because the existing return tables were
  already present; no migration was invented or applied unnecessarily.
- Return request idempotency and multiple-payment refund allocation require a
  future schema/business-rule decision.
- Full emulator walkthrough for return/refund UI is deferred until that UI
  contract is approved.
- Phase 2 remains blocked until these limitations are explicitly accepted or
  implemented.
