# P5 Inventory — Implementation Plan

**Goal:** Stok sebagai movement ledger (D-014): stok awal, penyesuaian, stock opname,
kartu stok, dengan cached balance tersinkron atomic. UI Stok di menu Lainnya.

**Spec:** FR-STOCK-001/002, PRD D, DESAIN §15/§31, amendment #8, D-009/D-014.

## Rules

- Setiap perubahan stok = 1 baris STOCK_MOVEMENT + update cache
  `products.stock_quantity_micro` dalam SATU transaction.
- Tipe: opening_balance / adjustment_in / adjustment_out / stock_opname
  (purchase_in/sale_out/sales_return_in menyusul di P6).
- Guard: hasil stok tidak boleh negatif → Failure(STOCK_INSUFFICIENT).
- unit_cost snapshot = product.cost_price_minor saat gerakan.
- Opname: delta = counted − current; simpan keduanya di note.

## Tasks

### P5-1 InventoryService (`lib/features/inventory/data/inventory_service.dart`)
- setOpeningBalance(productId, qtyMicro)
- adjustStock(productId, deltaMicro, note) — delta boleh ± 
- stockOpname(productId, countedQtyMicro, note)
- movementsFor(productId) — kartu stok (join tanggal sudah ada di row)

### P5-2 Tests (host, memory db): 8 kasus

### P5-3 UI: StockScreen(list+aksi), StockCardScreen(riwayat), bottom-sheet form qty

### P5-4 Router `/more/stock` + kartu; menu Lainnya aktifkan Stok

### CHECKPOINT P5
