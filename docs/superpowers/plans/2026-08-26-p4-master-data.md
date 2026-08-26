# P4 Master Data — Implementation Plan

**Goal:** CRUD penuh master data: kategori, satuan+konversi, produk(varian/harga/tier/SKU mp), pelanggan+tipe, supplier, salesman — repository teruji + UI sesuai DESAIN §13-14.

**Spec:** FR-PROD-001/002/003, PRD C/E/F/G/H, DESAIN §13/§14/§41, D-008/D-014 (stok TIDAK diedit di form produk; hanya lewat movement P5).

## Tasks

### P4-1 ReferenceRepository (kategori, satuan, tier, tipe pelanggan)
- ensureDefaults(businessId): unit `pcs`(dasar)+`dus`, tiers Retail(priority10)/Grosir(20),
  customer type Umum.
- CRUD sederhana + test host.

### P4-2 ProductRepository
- createProduct(draft) transaksional: product + units(konversi) + variants + prices.
- updateProduct serupa (replace children).
- archive/restore; getById detail (relations); search(query, filter enum
  all/active/inactive/lowStock/outOfStock) memakai cached stock micro vs minStock.
- Test: roundtrip penuh, unique sku per business, filter logic, archive.

### P4-3 Customer / Supplier / Salesman repositories
- CRUD + search; customer menyimpan typeId/salesmanId nullable.
- Test constraint & roundtrip.

### P4-4 Controllers Riverpod
- productsControllerProvider: AsyncNotifier list + query + filter; invalidate on save.
- referenceControllerProvider untuk kategori/satuan lists (watch drift streams).
- customers/suppliers/salesmen controllers serupa (sederhana).

### P4-5 UI
- Produk tab: search bar, filter chips, daftar (nama, sku, harga jual Rp, chip stok
  Aman/Menipis/Kritis/Habis dengan ikon), FAB + Produk → ProductFormScreen (stepper
  ringkas per DESAIN §41: Nama→Jenis→Harga→Satuan→Lanjutan collapsible).
- ProductDetailScreen: accordion Informasi/Harga/Stok(read-only)/Varian/Satuan/Lainnya;
  aksi Edit + Arsip.
- Pelanggan: list card (nama, telepon, tipe, piutang nanti), FAB, form sheet.
- Supplier & Salesman: list + dialog form.
- Lainnya: menu navigasi nyata (Pelanggan/Supplier/Salesman/Kategori & Satuan/Tipe
  Pelanggan/Toko Saya) — fitur Phase 2 disembunyikan (#16).
- Router: sub-routes dalam branch Produk & Lainnya.

### CHECKPOINT P4
analyze • test • apk • install emulator • commit • lapor owner sebelum P5 Inventory.
