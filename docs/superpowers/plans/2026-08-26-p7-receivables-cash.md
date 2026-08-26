# P7 Receivables & Cash — Implementation Plan

**Goal:** Piutang actionable (catat pembayaran → lunas) + kas sederhana
(pemasukan/pengeluaran/transfer) dengan ledger konsisten — semuanya atomik.

**Spec:** FR-AR-001, FR-CASH-001, D-007b (payment generik), D-010 (overdue derived),
amendment #14, DESAIN §18/§19.

## Rules

- Pembayaran piutang: 1 transaction = Payment(in/receivable_settlement)
  + RECEIVABLE_PAYMENT junction + update paid/remaining/status/closed_at
  + LedgerEntry debit + account balance. Guard: 0 < amount <= remaining.
- Transfer antar akun: 1 baris Payment(transfer, counter_account_id) + DUA
  LedgerEntry berpasangan + update saldo kedua akun.
- Expense/Income manual: Payment(other_expense|other_income, category) +
  ledger credit/debit + saldo.
- OVERDUE derived di UI: due_date < now && remaining > 0 (D-010).

## Tasks

### P7-1 ReceivableService (`lib/features/receivables/data/receivable_service.dart`)
### P7-2 FinanceService (`lib/features/finance/data/finance_service.dart`)
### P7-3 Tests keduanya
### P7-4 UI PiutangScreen + FinanceScreen; router `/more/piutang`, `/more/kas`; menu Lainnya
### CHECKPOINT P7
