# NotaKit — Design System & UX Specification

## 1. Tujuan Desain

NotaKit adalah aplikasi POS/penjualan dan manajemen usaha yang ditujukan untuk owner UMKM. Visual harus terasa modern, cepat dipahami, ringan, dan tidak terlihat seperti software kasir lama.

Prinsip utama:
- **Modern tetapi fungsional**: dekorasi tidak boleh mengganggu transaksi.
- **Readable first**: angka omzet, total, stok, dan laba harus mudah dipindai.
- **Touch first**: target sentuh nyaman untuk HP.
- **Progressive disclosure**: fitur kompleks ditampilkan ketika dibutuhkan.
- **One-hand friendly**: aksi penting mudah dijangkau ibu jari.
- **Trustworthy**: transaksi dan data keuangan terasa aman dan jelas.
- **Friendly**: bahasa UI Indonesia yang natural dan tidak terlalu teknis.

Target visual: kombinasi **modern fintech + productivity app + retail POS**, dengan nuansa profesional tetapi tetap hangat agar cocok untuk Gen Y dan Gen Z.

---

## 2. Arah Visual

### Karakter merek
NotaKit harus terasa:
- Cepat
- Bersih
- Pintar
- Ramah
- Praktis
- Profesional
- Tidak kuno

Hindari:
- Gradient berlebihan
- Skeuomorphism
- Terlalu banyak garis/border
- Dashboard penuh kartu kecil
- Warna-warni tanpa fungsi
- Font terlalu kecil
- Ikon dekoratif yang tidak membantu

---

## 3. Color Palette

### Primary — NotaKit Indigo
Digunakan untuk CTA utama, navigasi aktif, link, dan elemen interaktif.

- Primary 900: `#172554`
- Primary 800: `#1E3A8A`
- Primary 700: `#1D4ED8`
- Primary 600: `#2563EB`
- Primary 500: `#3B82F6`
- Primary 100: `#DBEAFE`
- Primary 50: `#EFF6FF`

Rekomendasi default: `#2563EB`.

### Accent — Mint
Digunakan untuk kondisi positif, laba, status selesai, dan insight.

- Accent 700: `#047857`
- Accent 600: `#059669`
- Accent 500: `#10B981`
- Accent 100: `#D1FAE5`
- Accent 50: `#ECFDF5`

### Warning — Amber
- Warning 700: `#B45309`
- Warning 600: `#D97706`
- Warning 500: `#F59E0B`
- Warning 100: `#FEF3C7`
- Warning 50: `#FFFBEB`

### Danger — Red
- Danger 700: `#B91C1C`
- Danger 600: `#DC2626`
- Danger 500: `#EF4444`
- Danger 100: `#FEE2E2`
- Danger 50: `#FEF2F2`

### Neutral
- Neutral 950: `#0F172A`
- Neutral 900: `#111827`
- Neutral 800: `#1F2937`
- Neutral 700: `#374151`
- Neutral 600: `#4B5563`
- Neutral 500: `#6B7280`
- Neutral 400: `#9CA3AF`
- Neutral 300: `#D1D5DB`
- Neutral 200: `#E5E7EB`
- Neutral 100: `#F3F4F6`
- Neutral 50: `#F8FAFC`
- White: `#FFFFFF`

### Semantic usage
- Biru: action/primary/selected.
- Hijau: laba, lunas, berhasil, stok aman.
- Kuning: perlu perhatian, stok menipis, belum diproses.
- Merah: gagal, hutang jatuh tempo, stok kritis, destructive action.
- Abu: metadata, secondary information.

Jangan memakai warna status sebagai satu-satunya pembeda; gunakan icon + label agar aksesibel.

---

## 4. Dark Mode

Dark mode wajib didukung setelah light mode stabil.

Gunakan:
- Background utama: `#0B1220`
- Surface: `#111827`
- Surface elevated: `#1F2937`
- Text primary: `#F8FAFC`
- Text secondary: `#CBD5E1`
- Divider: `#334155`

Primary di dark mode dapat memakai `#60A5FA` agar kontras tetap jelas.

Hindari black `#000000` sebagai background utama karena terlalu kontras dan terasa keras.

---

## 5. Typography

### Font
Rekomendasi utama: **Inter**.

Alternatif Flutter: `GoogleFonts.inter` atau bundle font lokal untuk pengalaman offline yang konsisten.

### Scale
- Display: 32sp / 38 line-height / 700
- H1: 28sp / 34 / 700
- H2: 24sp / 30 / 700
- H3: 20sp / 26 / 700
- Title: 18sp / 24 / 600
- Body Large: 16sp / 24 / 400
- Body: 14sp / 20 / 400
- Caption: 12sp / 16 / 500
- Numeric KPI: 24–32sp / 1.1 / 700

Nominal angka uang menggunakan font weight 700 dan alignment kanan jika berada dalam tabel/list transaksi.

### Formatting uang
Default Indonesia:
- `Rp 125.000`
- Jangan gunakan terlalu banyak digit desimal untuk UI penjualan.
- Tampilkan desimal hanya saat data memang membutuhkan.

---

## 6. Spacing & Grid

Gunakan spacing berbasis 4pt:

`4, 8, 12, 16, 20, 24, 32, 40, 48`

Default horizontal page padding: **16dp**.

Card spacing: **12–16dp**.

Section spacing: **24dp**.

Untuk layar tablet, naikkan horizontal padding menjadi 24–32dp.

---

## 7. Radius, Elevation, dan Surface

### Radius
- Small: 8dp
- Medium: 12dp
- Large: 16dp
- Extra: 20dp
- Bottom sheet: 24dp bagian atas

### Card
Gunakan surface bersih dengan border tipis `#E5E7EB` atau shadow sangat halus.

Hindari shadow berat.

### Buttons
- Small: radius 10dp
- Regular: radius 12dp
- Floating/action: radius 16dp

---

## 8. Navigation UX

Untuk HP gunakan **Bottom Navigation** dengan 5 destinasi utama:

1. **Beranda**
2. **Penjualan**
3. **Produk**
4. **Laporan**
5. **Lainnya**

Aksi paling penting, **Buat Nota**, menjadi primary action yang selalu mudah diakses dari Beranda dan Penjualan.

Jangan menaruh terlalu banyak menu utama di bottom navigation.

### Drawer / More
Menu sekunder:
- Pelanggan
- Salesman
- Supplier
- Stok
- Kas & Bank
- Marketplace
- Online Order
- Printer
- Backup & Restore
- Pengaturan
- Tentang

---

## 9. Home Dashboard

Beranda harus menjawab empat pertanyaan owner:

1. Hari ini jual berapa?
2. Untung berapa?
3. Ada hutang/piutang yang perlu diperhatikan?
4. Ada stok yang bermasalah?

### Struktur
1. Greeting + tanggal
2. Quick action
3. KPI cards
4. Ringkasan penjualan
5. Insight stok
6. Piutang jatuh tempo
7. Produk terlaris

### KPI cards
Jangan menampilkan lebih dari 4 KPI utama sekaligus.

Contoh:
- Omzet hari ini
- Laba hari ini
- Transaksi hari ini
- Piutang

Gunakan card yang relatif besar untuk angka utama.

---

## 10. Quick Actions

Di dashboard:
- `+ Buat Nota`
- Tambah Produk
- Tambah Pelanggan
- Catat Pengeluaran

Primary CTA harus paling jelas.

Gunakan icon + text; jangan icon-only untuk fungsi bisnis yang penting.

---

## 11. UX Transaksi / Buat Nota

Ini adalah layar terpenting aplikasi.

### Flow ideal
`Buat Nota → pilih pelanggan → tambah item → ubah qty → diskon → pembayaran → selesai`

Jangan membuat user berpindah banyak halaman.

### Layout
Top:
- Nomor nota
- Tanggal
- Customer

Middle:
- Search produk
- Barcode scan
- List item

Bottom:
- Subtotal
- Diskon
- Total
- Pembayaran
- Kembalian
- CTA `Simpan & Cetak` / `Simpan`

### Product picker
Search harus menjadi fokus utama.

Support:
- Nama
- Barcode
- SKU
- Kategori

Hasil harus menampilkan:
- Nama
- Harga
- Stok
- Satuan

Tap item sekali untuk menambahkan.

---

## 12. POS Speed Principles

Untuk kasir, jumlah tap harus minimum.

Target flow:
- Search produk: 1 tap
- Add produk: 1 tap
- Quantity: 1 tap
- Bayar: 1 tap

Gunakan bottom sheet untuk edit quantity/diskon agar user tidak kehilangan konteks transaksi.

Keyboard numerik harus digunakan untuk:
- Qty
- Harga manual
- Nominal pembayaran
- Diskon persen
- Diskon nominal

---

## 13. Product UI

List Produk harus cepat dipindai.

Setiap row:
- thumbnail kecil
- nama produk
- SKU/barcode
- harga
- stok
- status stok

Filter chips:
- Semua
- Stok rendah
- Habis
- Aktif
- Nonaktif

FAB:
`+ Produk`

### Product detail
Gunakan section accordion/card:

- Informasi dasar
- Harga
- Stok
- Varian
- Satuan
- Supplier
- Marketplace
- Berat & volume
- Catatan

Field lanjutan tidak perlu memenuhi layar pertama.

---

## 14. Customer UI

Pelanggan harus terasa seperti contact manager sederhana.

Card pelanggan:
- Nama
- Nomor telepon
- Tipe pelanggan
- Total transaksi
- Piutang

Quick action:
- Telepon
- WhatsApp
- Buat nota
- Bayar piutang

---

## 15. Inventory UX

Stok harus menggunakan bahasa yang mudah:

- **Aman**
- **Menipis**
- **Kritis**
- **Habis**

Jangan hanya menampilkan warna.

Detail stok:
- Stok saat ini
- Minimum stok
- Nilai stok
- Pergerakan stok
- Riwayat penyesuaian

---

## 16. Laporan UX

Laporan harus bisa dipahami dalam 5 detik pertama.

### Filter utama
- Hari ini
- Kemarin
- 7 hari
- 30 hari
- Bulan ini
- Custom

### Hierarki
1. KPI
2. Grafik
3. Breakdown
4. Detail tabel

Jangan memulai laporan dengan tabel panjang.

### Grafik
Gunakan grafik sederhana:
- Line chart untuk tren
- Bar chart untuk perbandingan
- Donut hanya untuk komposisi kecil

Hindari chart 3D.

---

## 17. Analisa Penjualan

Tampilkan insight seperti:
- Penjualan naik/turun
- Produk terlaris
- Hari paling ramai
- Jam ramai
- Kategori terbaik
- Pelanggan terbesar

Bahasa insight harus natural:

> “Penjualan minggu ini naik 12% dibanding minggu lalu.”

> “Produk X menjadi item terlaris bulan ini.”

Insight tidak boleh terasa seperti laporan korporat.

---

## 18. Cash & Bank UX

Tampilkan account cards:
- Kas
- Bank
- E-wallet

Setiap akun:
- Saldo
- transaksi terakhir

Gunakan timeline sederhana untuk arus kas.

---

## 19. Piutang UX

Piutang harus actionable.

Segment:
- Semua
- Belum jatuh tempo
- Jatuh tempo
- Terlambat
- Lunas

CTA:
`Catat Pembayaran`

Gunakan warning secara proporsional, jangan semua piutang dibuat merah.

---

## 20. Marketplace & Online Order

Marketplace diletakkan di menu sekunder agar tidak mengganggu POS offline.

Tampilkan connection status:
- Terhubung
- Perlu login
- Error
- Sinkronisasi

Online Order memakai status chip:
- Baru
- Diproses
- Siap
- Selesai
- Dibatalkan

Gunakan timeline untuk status order.

---

## 21. Restaurant/Cafe Mode

Dalam mode restoran:
- Table layout lebih visual.
- Order dapat dikaitkan dengan meja.
- Modifier/add-on muncul sebagai bottom sheet.
- Tombol `Tambah Item` tetap besar.
- Split bill dan pembayaran dilakukan di satu alur.

Hindari penggunaan pola restoran jika mode usaha biasa aktif.

---

## 22. Minimarket Mode

Prioritas:
- Barcode scan
- Search cepat
- Numeric keypad
- Cart
- Total besar
- Pembayaran cepat

Gunakan layout density lebih tinggi dibanding dashboard owner.

---

## 23. Backup & Pindah HP

UX harus membuat backup terasa sederhana.

### Menu
`Pengaturan → Data → Backup & Restore`

Primary action:
`Backup Sekarang`

Secondary:
`Restore Data`

### Export
Pilihan:
- Backup terenkripsi NotaKit
- JSON biasa
- Excel untuk data yang memang relevan

### Backup terenkripsi
Ekstensi contoh:
`.notakit`

Flow:
1. Pilih lokasi penyimpanan
2. Masukkan password backup
3. Konfirmasi password
4. Encrypt
5. Buat file
6. Verifikasi checksum

Restore:
1. Pilih file
2. Masukkan password
3. Validasi file
4. Preview metadata
5. Konfirmasi restore
6. Restore transactionally

Jangan menghapus database aktif sebelum validasi restore berhasil.

---

## 24. Empty State

Empty state harus memberi arah.

Contoh:

**Belum ada produk**
“Tambahkan produk pertama agar kamu bisa mulai membuat nota.”

CTA:
`Tambah Produk`

Jangan menggunakan empty state kosong atau hanya teks “Tidak ada data”.

---

## 25. Loading State

Gunakan skeleton untuk halaman dashboard/list.

Untuk aksi pendek gunakan progress indicator.

Jangan menampilkan spinner tanpa konteks lebih dari beberapa detik.

---

## 26. Error State

Pesan error harus menjelaskan:
- apa yang terjadi
- dampaknya
- apa yang bisa dilakukan

Contoh buruk:
`Error 500`

Contoh baik:
`Data belum berhasil disimpan. Periksa ruang penyimpanan lalu coba lagi.`

---

## 27. Confirmation & Destructive Action

Hapus data penting menggunakan confirmation dialog.

Dialog harus menyebut objeknya:

> “Hapus produk ‘Kopi Arabica’?”

Untuk penghapusan transaksi yang sudah memiliki pembayaran, gunakan guard yang lebih ketat.

---

## 28. Toast / Snackbar

Gunakan snackbar untuk hasil aksi ringan:
- Produk berhasil ditambahkan
- Nota berhasil disimpan
- Backup berhasil dibuat

Jangan gunakan snackbar untuk error yang membutuhkan keputusan user.

---

## 29. Accessibility

Minimum:
- Touch target 44×44dp atau lebih.
- Kontras warna teks memenuhi WCAG AA.
- Jangan mengandalkan warna saja.
- Support font scaling.
- Label screen reader untuk icon-only button.
- Jangan memakai teks terlalu kecil.

---

## 30. Responsive Flutter Layout

Breakpoints konseptual:
- Compact phone: `< 600dp`
- Tablet: `600–839dp`
- Large tablet: `>= 840dp`

Pada tablet:
- NavigationRail dapat digunakan.
- List dan detail bisa split view.
- Dashboard dapat memakai dua kolom.

Pada phone:
- Bottom navigation.
- Single-column.
- Bottom sheet untuk detail/edit cepat.

---

## 31. Flutter Component Library

Semua komponen UI harus reusable.

Struktur contoh:

```text
lib/core/theme/
├── app_colors.dart
├── app_typography.dart
├── app_spacing.dart
├── app_radius.dart
├── app_theme.dart
└── app_icons.dart

lib/shared/widgets/
├── nk_button.dart
├── nk_card.dart
├── nk_text_field.dart
├── nk_search_field.dart
├── nk_money_text.dart
├── nk_status_chip.dart
├── nk_empty_state.dart
├── nk_error_state.dart
├── nk_loading.dart
├── nk_bottom_sheet.dart
└── nk_confirm_dialog.dart
```

Prefix `NK` dapat digunakan untuk menandai komponen internal NotaKit.

---

## 32. Button Hierarchy

### Primary
Satu CTA utama per area.

Contoh:
`Simpan Nota`

### Secondary
Untuk aksi pendamping.

Contoh:
`Simpan Draft`

### Tertiary
Text button untuk aksi ringan.

### Destructive
Hapus/batalkan dengan warna danger dan konfirmasi.

Jangan mempunyai tiga tombol primary berdampingan.

---

## 33. Iconography

Gunakan satu family icon secara konsisten, misalnya Material Symbols.

Aturan:
- Default 24dp
- Secondary 20dp
- Small metadata 18dp
- Hindari campur icon set berbeda tanpa alasan.

Icon harus intuitif, bukan dekoratif.

---

## 34. UX Writing / Microcopy

Gunakan bahasa Indonesia yang sederhana.

Pilih:
- `Tambah Produk`
- `Buat Nota`
- `Catat Pembayaran`
- `Backup Sekarang`
- `Pulihkan Data`

Hindari:
- `Execute transaction`
- `Persist data`
- `Synchronize entity`

Istilah teknis boleh muncul di halaman diagnosis/debug, bukan di flow bisnis.

---

## 35. Tone of Voice

Nada:
- Ramah
- Singkat
- Meyakinkan
- Tidak menggurui

Contoh:
> “Data sudah aman tersimpan di perangkat ini.”

> “Backup terakhir 2 hari lalu.”

> “Stok Kopi Arabica tinggal 3 pcs.”

---

## 36. Visualisasi Data

Gunakan angka besar untuk KPI dan grafik sederhana untuk tren.

Contoh kartu:

```text
Omzet Hari Ini
Rp 2.450.000
↑ 12,4% dari kemarin
```

Jangan menjejalkan lebih dari dua metadata sekunder dalam satu KPI card.

---

## 37. Motion Design

Animasi harus cepat dan subtle.

Rekomendasi:
- Page transition: 180–250ms
- Bottom sheet: 220–280ms
- Snackbar: 180ms
- Button state: 100–150ms

Gunakan motion untuk memberi feedback, bukan hiasan.

Support `prefers-reduced-motion` equivalent behavior jika implementasi platform memerlukannya.

---

## 38. Onboarding

Onboarding maksimal 3 langkah.

### Step 1
“Kenalkan toko kamu”

Input:
- Nama usaha
- Jenis usaha

### Step 2
“Mulai dari data kamu”

Pilihan:
- Data kosong
- Import backup
- Data contoh/demo

### Step 3
“Siap jualan”

CTA:
`Mulai dengan NotaKit`

Jangan membuat onboarding panjang sebelum user dapat mencoba aplikasi.

---

## 39. Demo Data

Mode demo harus membantu memahami aplikasi.

Data contoh:
- Produk
- Pelanggan
- Transaksi
- Laporan

Berikan banner kecil:
`Mode Demo`

User dapat menghapus data demo secara eksplisit.

---

## 40. Search & Filter

Search global hanya bila memang berguna.

Per halaman gunakan search kontekstual.

Filter dapat berupa chips atau bottom sheet.

State filter harus jelas:
`Filter aktif: 2`

---

## 41. Form Design

Form mengikuti urutan logis dari sederhana → lanjutan.

Contoh Produk:
1. Nama
2. Jenis
3. Harga
4. Satuan
5. Stok
6. Field lanjutan

Required field harus terlihat jelas.

Validasi sebaiknya inline dan sedekat mungkin dengan field.

---

## 42. Mobile Safe Areas

Gunakan SafeArea untuk:
- status bar
- gesture/navigation area
- bottom action bar

CTA fixed di bawah harus memperhitungkan keyboard dan safe area.

---

## 43. Print Preview UX

Sebelum cetak:
- Preview nota
- Pilih printer
- Pilih ukuran
- Test print
- Cetak

Tampilkan status koneksi printer dengan jelas.

---

## 44. Privacy UX

Karena data lokal dan single owner:
- Jelaskan data disimpan di perangkat.
- Jelaskan kapan internet diperlukan.
- Jelaskan backup/restore.
- Jangan menggunakan bahasa subscription.

Pengguna harus memahami bahwa kehilangan perangkat tanpa backup dapat menyebabkan kehilangan data lokal.

---

## 45. Security UX

Untuk backup terenkripsi:
- Jangan kirim password ke server.
- Jangan tampilkan password di log.
- Beri peringatan bahwa password yang hilang tidak dapat dipulihkan.

Teks contoh:
> “Password backup tidak bisa dipulihkan oleh NotaKit. Simpan password di tempat aman.”

---

## 46. UI Priority Matrix

### Paling penting
- Buat Nota
- Produk
- Pembayaran
- Total
- Stok

### Penting
- Pelanggan
- Piutang
- Laporan
- Kas/Bank

### Sekunder
- Salesman
- Supplier
- Marketplace
- Online Order
- Export/import

### Advanced
- Restaurant mode
- Minimarket mode
- Analisa lanjutan
- Integrasi marketplace

---

## 47. Screen Inventory

Minimum screen yang harus memiliki desain:

### Core
- Splash
- Onboarding
- Beranda
- Penjualan
- Detail nota
- Buat nota
- Payment
- Produk
- Tambah produk
- Detail produk
- Pelanggan
- Detail pelanggan

### Inventory & finance
- Stok
- Detail pergerakan stok
- Supplier
- Salesman
- Piutang
- Kas & Bank
- Transaksi kas

### Reporting
- Summary
- Rekap harian
- Laba penjualan
- Laba bersih
- Arus kas
- Nilai stok
- Analisa penjualan
- Riwayat aktivitas

### Advanced
- Marketplace
- Online Order
- Detail order
- Restaurant mode
- Table view
- Minimarket POS

### Utility
- Printer
- Printer setup
- Backup
- Restore
- Export/import
- Pengaturan
- Toko Saya
- Preferensi
- Password/security
- Demo data
- About

---

## 48. Recommended Visual Direction

Referensi rasa visual yang ingin dicapai:

**Linear/Notion/Stripe-style clarity + modern fintech + POS speed**, tetapi tetap menggunakan bahasa visual sendiri agar NotaKit memiliki identitas.

Karakter akhir:

> “Aplikasi bisnis yang terasa seperti aplikasi modern yang dipakai sehari-hari, bukan software kasir lama.”

---

## 49. Golden Rules

1. Setiap layar harus punya satu primary action.
2. User harus memahami angka penting tanpa membaca panjang.
3. Transaksi harus dapat dibuat secepat mungkin.
4. Gunakan warna sebagai semantic signal, bukan dekorasi.
5. Detail lanjutan disembunyikan sampai diperlukan.
6. Semua destructive action harus jelas.
7. Semua data penting harus mudah dibackup.
8. UI harus nyaman digunakan dengan satu tangan.
9. Jangan membuat dashboard terlalu padat.
10. Konsistensi komponen lebih penting daripada variasi visual.

---

## 50. Definition of Done untuk UI

Sebuah fitur dianggap siap secara desain apabila:

- Memiliki loading state.
- Memiliki empty state.
- Memiliki error state.
- Memiliki success feedback.
- Memiliki validasi form.
- Memiliki confirmation untuk destructive action.
- Mendukung light mode.
- Tidak rusak pada dark mode.
- Memiliki touch target yang nyaman.
- Memiliki accessibility label bila diperlukan.
- Mendukung phone dan tablet sesuai breakpoint.
- Tidak membutuhkan pengetahuan teknis untuk memahami flow.
