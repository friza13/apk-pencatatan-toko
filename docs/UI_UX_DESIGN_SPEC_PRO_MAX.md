# NotaKit — UI/UX Design Architecture & Specification Pro Max
**Dokumen Spesifikasi Desain Sistem, Interaksi Mobile POS, & Arsitektur Visual Ergonomis UMKM**

*Versi:* 2.0-PRO-MAX  
*Domain:* Mobile Point-of-Sale (POS), Retail, Grosir, & Finansial UMKM  
*Stack:* Flutter 3.44.x / Dart 3.12.x  
*Standar Aksesibilitas:* WCAG 2.2 AA / AAA Compliant (Contrast $\ge 4.5:1$, Target Size $\ge 48\text{dp}$)  
*Target Perangkat:* Android Smartphone & Tablet (360dp – 1024dp)  

---

## 1. Executive Summary & Filosofi Desain

NotaKit dirancang sebagai instrumen kerja harian pemilik usaha tunggal (*single-owner*) dan kasir UMKM. Pada lingkungan kasir fisik, setiap detik berharga: antrean pelanggan, kondisi pencahayaan toko yang beragam (terang benderang hingga remang-remang), serta penggunaan dengan satu tangan (*one-handed operation*) menuntut desain yang **ergonomis, berkecepatan tinggi, bebas friksi, dan minim beban kognitif (*low cognitive load*)**.

### Prinsip Inti Desain UI/UX Pro Max:
1. **Speed & Ergonomics First (Thumb-Zone Priority):**
   Aksi kritis (tombol bayar, penambahan produk, input uang kas, konfirmasi cetak) ditempatkan di zona jangkauan ibu jari (40% layar bagian bawah).
2. **High-Contrast Data Legibility:**
   Angka finansial (omzet, laba, total tagihan, kembalian) menggunakan tipografi angka tabular (*tabular figures*) berbobot medium-bold dengan kontras rasio minimal $4.5:1$ terhadap latar belakang.
3. **Fitts’s Law & Minimum Touch Target:**
   Seluruh tombol dan area sentuh interaktif memiliki dimensi minimal **$48 \times 48\text{dp}$** dengan jarak pemisah (*touch spacing*) minimal **$8\text{dp}$** untuk mencegah salah pencet (*fat-finger errors*).
4. **Context-Aware Input & Virtual Keyboard Safety:**
   Mencegah *layout shift* mendadak. Input angka memicu keypad numerik secara terarah; kolom pencarian tidak memunculkan keyboard virtual secara otomatis (*no intrusive autofocus*) yang menutupi katalog barang.
5. **Multi-Sensory Feedback (Visual + Haptic):**
   Setiap interaksi kasir (scan barcode, tambah barang, tekan tombol bayar) memberikan respon instan berupa umpan balik visual (*micro-elevation/ink ripple*) dan haptic feedback ringan.

---

## 2. Audit & Analisis Komparatif: UX Saat Ini vs Rekomendasi Pro Max

| Aspek UX | Kondisi Saat Ini (Legacy) | Permasalahan Lapangan | Solusi Rekomendasi UI/UX Pro Max |
|---|---|---|---|
| **Layar Kasir (POS Screen)** | Kolom pencarian dengan `autofocus: true`, dropdown hasil pencarian terbatas tinggi $220\text{dp}$, di bawahnya daftar keranjang. | Keyboard virtual Android langsung terbuka saat buka layar dan menutupi 50% layar. Kasir yang ingin scan barcode atau melihat daftar produk terhalang. | **Mode Katalog Grid Visual + Barcode Mode**. Nonaktifkan autofocus otomatis. Tampilkan kartu produk cepat sentuh (kategori pill horizontal + product tiles). |
| **Penyetelan Jumlah (Qty Stepper)** | Menggunakan `IconButton` standar kecil (`Icons.remove_circle_outline`, `Icons.add_circle_outline`) di baris daftar. | Kasir yang melayani transaksi cepat kesulitan menekan tombol minus/plus kecil secara akurat saat bergerak cepat. | **Stepper Sentuh Ergonomis ($48 \times 48\text{dp}$)** dengan latar tonal kontras, haptic click, dan kemampuan ketuk angka untuk input manual jika kuantitas besar (> 20 pcs). |
| **Alur Pembayaran Tunai** | `TextField` input angka nominal polos di modal bottom-sheet tanpa rekomendasi uang pecahan. | Kasir harus mengetik manual nominal uang pembayaran (misal `50000`, `100000`). Memperlambat proses kasir 3–5 detik per transaksi. | **Quick Cash Denomination Chips**: Tombol instan **"Uang Pas"**, **"+Rp10.000"**, **"+Rp20.000"**, **"Rp50.000"**, **"Rp100.000"**, dan kalkulator kembalian real-time yang sangat mencolok. |
| **Dashboard KPI** | Kartu metrik vertikal polos dengan teks kecil dan `FutureBuilder` yang menampilkan spinner berulang. | Informasi penting (omzet vs laba) terlihat monoton dan tidak langsung menangkap perhatian visual pemilik toko. | **Bento-Grid Dashboard** modern: Hero Metric Omzet & Laba dengan aksen pill pertumbuhan, visual bar penjualan harian, dan notifikasi stok menipis beraksen amber tegas. |
| **Pemilihan Varian & Satuan** | Modal bottom sheet daftar vertikal panjang teks rapat. | Sulit membedakan varian rasa/warna dan satuan alternatif dalam sekilas pandang. | **Segmented Visual Pill Selector**: Pilihan varian dalam bentuk pill grid horizontal dengan badge sisa stok, diikuti satuan konversi dalam radio tile modern. |
| **Struk & Dialog Cetak** | Kotak teks hitam monospaced kaku dengan tombol segmented kecil. | Kurang merepresentasikan bentuk fisik struk belanja; kasir ragu apakah struk sudah pas untuk kertas 58mm atau 80mm. | **Live Thermal Receipt Simulation**: Tampilan lembaran kertas struk putih berbayang halus (*paper shadow*) dengan efek gerigi sobekan kertas di atas latar abu-abu netral. |

---

## 3. Sistem Desain Baru (NotaKit Pro Max Design Tokens)

### 3.1. Color Palette (Semantic & Accessible)

Palet warna diperbarui dengan memadukan stabilitas finansial (*Trust Blue*), energi konversi retail (*Vibrant Mint / Emerald*), serta penanda waspada yang aman bagi mata kasir.

```text
┌────────────────────────────────────────────────────────────────────────┐
│ PRIMARY: NotaKit Electric Indigo (#2563EB)                            │
│ Digunakan untuk: Navigasi Aktif, CTA Utama, Badge Brand, Focus Ring   │
├────────────────────────────────────────────────────────────────────────┤
│ ACCENT / SUCCESS: Emerald Growth (#059669 / #10B981)                   │
│ Digunakan untuk: Laba, Pembayaran Lunas, Kas Masuk, Stok Aman          │
├────────────────────────────────────────────────────────────────────────┤
│ WARNING: Amber Pulse (#D97706 / #F59E0B)                               │
│ Digunakan untuk: Stok Menipis, Piutang Mendekati Jatuh Tempo, Draft   │
├────────────────────────────────────────────────────────────────────────┤
│ DANGER: Crimson Alert (#DC2626 / #EF4444)                              │
│ Digunakan untuk: Void, Piutang Lewat Jatuh Tempo, Stok Habis, Delete  │
└────────────────────────────────────────────────────────────────────────┘
```

#### Token Warna Lengkap (Light & Dark Mode):

| Token Nama | Nilai Light Mode | Nilai Dark Mode | Penerapan Komponen | Rasio Kontras (WCAG) |
|---|---|---|---|---|
| `colorBackground` | `#F8FAFC` (Slate 50) | `#0B1220` (Deep Space) | Latar belakang layar aplikasi | 14.2:1 terhadap text primary |
| `colorSurface` | `#FFFFFF` (Pure White) | `#111827` (Gray 900) | Kartu produk, bottom sheet, menu bar | 12.8:1 terhadap text primary |
| `colorSurfaceElevated`| `#FFFFFF` (Shadow md) | `#1F2937` (Gray 800) | Dialog modal, floating action button | 10.5:1 terhadap text primary |
| `colorPrimary` | `#2563EB` (Indigo 600) | `#3B82F6` (Blue 500) | Tombol utama "Bayar", Tab aktif | 5.1:1 terhadap white text |
| `colorPrimaryContainer`|`#EFF6FF` (Blue 50) | `#1E3A8A` (Blue 900) | Latar belakang chip terpilih | 6.2:1 terhadap primary text |
| `colorTextPrimary` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Judul nota, angka omzet, nama produk | 15.1:1 terhadap surface |
| `colorTextSecondary` | `#475569` (Slate 600) | `#94A3B8` (Slate 400) | Metadata (jam, SKU, kategori, unit) | 4.8:1 (Safe for text) |
| `colorTextMuted` | `#64748B` (Slate 500) | `#64748B` (Slate 500) | Placeholder input, divider label | 3.5:1 (Non-critical text) |
| `colorBorder` | `#E2E8F0` (Slate 200) | `#334155` (Slate 700) | Garis batas kartu, outline input | 3.1:1 (Safe UI boundary) |
| `colorSuccess` | `#059669` (Emerald 600) | `#10B981` (Emerald 500)| Angka Laba, Badge Lunas | 4.9:1 terhadap white text |
| `colorWarning` | `#D97706` (Amber 600) | `#F59E0B` (Amber 500) | Notifikasi stok menipis | 4.6:1 terhadap black text |
| `colorDanger` | `#DC2626` (Red 600) | `#EF4444` (Red 500) | Tombol Hapus, Piutang Overdue | 5.2:1 terhadap white text |

---

### 3.2. Tipografi & Skala Teks (Tabular Figures First)

Aplikasi POS memerlukan **Tabular Figures** (`fontFeatures: [FontFeature.tabularFigures()]`) agar digit nominal mata uang tersusun lurus rapi ke bawah, memudahkan kasir menghitung dalam hitungan detik tanpa mata lelah.

* **Font Keluarga:**
  * **Headings & Display:** `Rubik` atau `Lexend` (modern, terbuka, kurva ramah kasir).
  * **Body, Form & Angka:** `Inter` / `Nunito Sans` (resolusi tinggi, glyph angka monospaced-width).

```text
Display Large  : 28pt / Bold      -> Angka Omzet Utama, Total Kembalian
Title Large    : 20pt / SemiBold  -> Total Tagihan Kasir, Judul Nota
Title Medium   : 16pt / SemiBold  -> Nama Produk di Keranjang, Judul Seksi
Body Large     : 15pt / Regular   -> Nilai Input Form, Teks Struk
Body Medium    : 13pt / Medium    -> Kuantitas, Subtitle, Kategori
Label Small    : 11pt / Bold CAPS -> Status Badge (LUNAS, KREDIT, VOID)
```

---

### 3.3. Token Spacing, Radius, & Elevation

* **Grid Spacing (4pt / 8pt Scale):**
  * `spacing-xs`: `4dp` (Jarak internal icon-ke-label)
  * `spacing-sm`: `8dp` (Jarak antar chip, padding compact)
  * `spacing-md`: `12dp` (Jarak antar item dalam kartu)
  * `spacing-lg`: `16dp` (Padding standar layar mobile)
  * `spacing-xl`: `24dp` (Jarak antar blok seksi informasi)
  * `spacing-2xl`: `32dp` (Pemisah vertikal modal container)

* **Corner Radii:**
  * `radius-sm`: `8dp` (Tombol kecil, chip, input field)
  * `radius-md`: `12dp` (Kartu produk, metric tiles, preview dialog)
  * `radius-lg`: `16dp` (Modal bottom sheet top corners, summary card)
  * `radius-full`: `999dp` (Pill status, Floating Counter Badge)

* **Elevations (Shadows):**
  * `elevation-0`: Flat dengan border `1dp` `colorBorder` (desain bersih harian).
  * `elevation-1`: Subtle Lift (`blur: 4dp, y: 2dp, color: rgba(0,0,0,0.04)`).
  * `elevation-2`: Modal / Sticky Bottom Bar (`blur: 16dp, y: -4dp, color: rgba(0,0,0,0.08)`).

---

## 4. Perancangan Ulang Layar Utama (Detailed UI/UX Specs)

### 4.1. Layar Beranda / Dashboard (`DashboardScreen`)

```text
┌──────────────────────────────────────────────────────────┐
│ [Logo] Toko Berkah Makmur                   [Shift/Sync] │
│ Selamat Pagi, Budi (Owner)                               │
├──────────────────────────────────────────────────────────┤
│ ┌─ OMZET HARI INI ────────────┐ ┌─ LABA ESTIMASI ──────┐ │
│ │ Rp 3.450.000                │ │ Rp 820.000           │ │
│ │ [▲ +12% dari kemarin]       │ │ [Margin 23.7%]       │ │
│ └─────────────────────────────┘ └──────────────────────┘ │
│ ┌─ TRANSAKSI ─────────────────┐ ┌─ PIUTANG BERJALAN ───┐ │
│ │ 48 Nota  •  42 Lunas        │ │ Rp 450.000 (3 Org)   │ │
│ └─────────────────────────────┘ └──────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│ AKSI CEPAT (One-Tap Shortcuts)                           │
│ [ ➕ Buat Nota ]  [ 📦 Produk ]  [ 💰 Kas ]  [ 📑 Laporan ]│
├──────────────────────────────────────────────────────────┤
│ PERLU PERHATIAN (Actionable Insights)                    │
│ ⚠️ 3 Produk stok menipis (< 5 pcs)        [Lihat Stok >] │
│ 🔔 1 Piutang jatuh tempo hari ini         [Tagih WA >]   │
├──────────────────────────────────────────────────────────┤
│ TRANSAKSI TERAKHIR                                       │
│ • #INV-0048 • Tunai Rp 45.000 • 2 mnt lalu      [LUNAS]  │
│ • #INV-0047 • Tempo Rp 120.000 (Pak Joko)       [TEMPO]  │
└──────────────────────────────────────────────────────────┘
```

* **Keunggulan Ergonomi:**
  * 4 KPI Finansial dikelompokkan dalam **2x2 Bento Cards** simetris.
  * Status "Perlu Perhatian" menggunakan kartu peringatan bernuansa amber yang langsung memiliki aksi *deep-link* sekali sentuh.
  * FAB "Buat Nota" tetap melayang di pojok kanan bawah dengan ukuran besar ($56\text{dp}$) untuk memfasilitasi pembuatan nota dalam hitungan detik.

---

### 4.2. Layar POS Kasir & Keranjang (`NewSaleScreen`)

Layar POS didesain ulang menjadi layout fleksibel yang mendukung **Sentuh Cepat (Fast Touch Visual)** dan **Barcode Cepat (Scan Only)** tanpa konflik keyboard.

```text
┌──────────────────────────────────────────────────────────┐
│ [←] Buat Nota Baru                      [ 🔍 ] [ 📷 Scan]│
├──────────────────────────────────────────────────────────┤
│ [ Semua ] [ Makanan ] [ Minuman ] [ Rokok ] [ Sembako ]  │ <- Horizontal Category Chips
├──────────────────────────────────────────────────────────┤
│ KATALOG CEPAT SENTUH                                     │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│ │ [Foto]       │ │ [Foto]       │ │ [Foto]       │       │
│ │ Teh Botol    │ │ Kopi Susu    │ │ Indomie Goreng       │
│ │ Rp 4.500     │ │ Rp 8.000     │ │ Rp 3.500     │       │
│ │ [Stok: 42]   │ │ [2 Varian]   │ │ [Stok: 120]  │       │
│ └──────────────┘ └──────────────┘ └──────────────┘       │
├──────────────────────────────────────────────────────────┤
│ KERANJANG BELANJA (3 Item)                [Hapus Semua]  │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Teh Botol Sosro 350ml               Rp 9.000         │ │
│ │ Rp 4.500 / botol                                     │ │
│ │           [ ➖ ]    2 botol    [ ➕ ]                 │ │
│ ├──────────────────────────────────────────────────────┤ │
│ │ Kopi Kenangan (Dingin - Normal Ice) Rp 18.000        │ │
│ │ Rp 18.000 / cup                                      │ │
│ │           [ ➖ ]    1 cup      [ ➕ ]                 │ │
│ └──────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────────┐ │
│ │ TOTAL: Rp 27.000 (2 Barang)                          │ │
│ │ [ ⚡ BAYAR SEKARANG (Rp 27.000)                   ]  │ │ <- Sticky Bottom Bar 56dp
│ └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

* **Interaksi Kunci:**
  * **Ketiadaan Gangguan Keyboard:** Saat membuka layar kasir, keyboard virtual **tidak dibuka secara otomatis**. Kasir langsung disuguhkan grid visual produk populer dan chip kategori.
  * **Floating Cart Bar:** Bar pembayaran selalu menempel (*sticky*) di bawah layar, memperlihatkan total rupiah dan total kuantitas secara real-time.
  * **Stepper Kuantitas 48dp:** Tombol `[ - ]` dan `[ + ]` memiliki area tap $48 \times 48\text{dp}$ dengan angka di tengah yang bila diketuk memunculkan modal *quick numpad* untuk memasukkan kuantitas ratusan (*bulk qty*).

---

### 4.3. Dialog / Sheet Pembayaran Instan (`PaymentSheet`)

```text
┌──────────────────────────────────────────────────────────┐
│ Pembayaran Nota                                      [X] │
│ Tagihan: Rp 73.500                                       │
├──────────────────────────────────────────────────────────┤
│ PILIH CEPAT NOMINAL DITERIMA                             │
│ [ Uang Pas (Rp 73.500) ]   [ Rp 75.000 ]   [ Rp 80.000 ] │
│ [ Rp 100.000           ]   [ Rp 150.000 ]  [ Manual... ] │
├──────────────────────────────────────────────────────────┤
│ DITERIMA: [ Rp 100.000                                 ] │
│ KEMBALIAN: Rp 26.500  (Warna Hijau Bold Besar 24pt)      │
├──────────────────────────────────────────────────────────┤
│ METODE PEMBAYARAN                                        │
│ (•) Tunai      ( ) QRIS/BCA      ( ) Tempo/Piutang       │
├──────────────────────────────────────────────────────────┤
│ [   SIMPAN & CETAK NOTA (ENTER)                       ]  │ <- Primary Button 56dp
└──────────────────────────────────────────────────────────┘
```

* **Ergonomi Penanganan Uang:**
  * Tombol **"Uang Pas"** secara otomatis mengisi nominal tagihan (0 kembalian), menyelesaikan transaksi dalam 1 ketukan.
  * Algoritma chip nominal secara otomatis menyarankan pecahan uang riil terdekat (misal tagihan 73.500 menyarankan 75.000, 80.000, 100.000).
  * Angka **Kembalian** ditampilkan dengan font display besar $24\text{pt}$ berwarna hijau cerah berlatar belakang kontras, memastikan kasir tidak salah memberikan kembalian fisik uang kertas.

---

### 4.4. Dialog Pemilihan Varian & Satuan Konversi

```text
┌──────────────────────────────────────────────────────────┐
│ Pilih Opsi Produk                                    [X] │
│ Kopi Susu Aren Gula Jawa                                 │
├──────────────────────────────────────────────────────────┤
│ VARIAN RASA / SUHU                                       │
│ [ Dingin / Regular ]  [ Dingin / Large (+3k) ]  [ Panas ]│
├──────────────────────────────────────────────────────────┤
│ SATUAN PENJUALAN                                         │
│ (•) Cup (Satuan Utama)                 - Rp 15.000       │
│ ( ) Paket 3 Cup (Diskon 10%)           - Rp 40.500       │
├──────────────────────────────────────────────────────────┤
│ JUMLAH:  [ ➖ ]    1    [ ➕ ]                           │
│ TOTAL: Rp 15.000                                         │
│ [ TAMBAHKAN KE KERANJANG                              ]  │
└──────────────────────────────────────────────────────────┘
```

* **Struktur Tervalidasi:**
  * Memisahkan secara tegas antara **Varian** (sifat item, misal ukuran/suhu) dan **Satuan Konversi** (faktor pengali stok, misal pcs vs dus).
  * Harga dinamis langsung terupdate saat kasir memilih opsi.

---

### 4.5. Dialog & Pratinjau Cetak Struk Thermal (`PrintSheet`)

```text
┌──────────────────────────────────────────────────────────┐
│ Pratinjau & Cetak Struk                              [X] │
│ [ 58 mm (Standar) ]     [ 80 mm (Lebar) ]                │
├──────────────────────────────────────────────────────────┤
│ ┌─ SIMULASI KERTAS THERMAL ────────────────────────────┐ │
│ │  ==================================================  │ │
│ │                 TOKO BERKAH MAKMUR                   │ │
│ │              Jl. Kaliurang Km 5, YK                  │ │
│ │  --------------------------------------------------  │ │
│ │  No: #INV-2026-0049          28/08/26 14:32          │ │
│ │  Kasir: Admin                Pelanggan: Umum         │ │
│ │  --------------------------------------------------  │ │
│ │  Teh Botol Sosro               Rp 9.000              │ │
│ │    2 botol X 4.500                                   │ │
│ │  Kopi Susu Aren               Rp 18.000              │ │
│ │    1 cup X 18.000                                    │ │
│ │  --------------------------------------------------  │ │
│ │  TOTAL                        Rp 27.000              │ │
│ │  TUNAI                        Rp 50.000              │ │
│ │  KEMBALI                      Rp 23.000              │ │
│ │  ==================================================  │ │
│ │         Terima kasih atas kunjungan Anda!            │ │
│ └──────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│ Status Printer: 🟢 Terhubung ke "Panda 58mm POS"         │
├──────────────────────────────────────────────────────────┤
│ [ 🖨️ CETAK NOTA (58mm) ]      [ ↗️ Bagikan PDF / WA ]     │
└──────────────────────────────────────────────────────────┘
```

* **Pengalaman Kasir:**
  * Memberikan kepastian visual 100% (*WYSIWYG*) mengenai perataan teks, garis potong, dan susunan rupiah sebelum kertas thermal benar-benar dicetak.
  * Status printer bluetooth ditampilkan dengan lampu indikator hijau/merah yang jelas.

---

## 5. Rencana Aksi Implementasi Bertahap (TDD Implementation Plan)

Pembaruan UI/UX akan diimplementasikan secara modular dalam 5 fase terukur:

### Fase 1: Fondasi Design Tokens & Tema Global
- Perbarui `lib/app/theme/app_colors.dart` dan `app_typography.dart`.
- Pastikan `AppTheme.light()` dan `AppTheme.dark()` memiliki nilai kontras WCAG AA yang lolos audit otomatis.
- Siapkan widget shared primitif: `NKButton`, `NKCard`, `NKBadge`, `NKTonalIcon`.

### Fase 2: Pustaka Komponen Khusus POS (POS Widgets)
- Buat `lib/shared/widgets/pos_quantity_stepper.dart` ($48\times48\text{dp}$, haptic click).
- Buat `lib/shared/widgets/quick_cash_chips.dart` (pilihan pecahan uang cerdas).
- Buat `lib/shared/widgets/product_pos_tile.dart` (kartu katalog sentuh cepat dengan badge stok).

### Fase 3: Rekonstruksi Layar Kasir (`NewSaleScreen`)
- Hapus `autofocus: true` dari search textfield agar tidak memicu keyboard virtual tanpa sengaja.
- Tambahkan filter kategori horizontal chip bar.
- Susun layout split: Grid Katalog Cepat di atas, Sticky Floating Cart Bar di bawah.
- Integrasikan `PaymentSheet` baru dengan kalkulator kembalian dan tombol nominal cerdas.

### Fase 4: Modernisasi Dashboard & Laporan
- Terapkan 2x2 Bento KPI Cards di `DashboardScreen`.
- Perbarui kartu stok menipis dan piutang jatuh tempo dengan visual pill yang lebih kontras.
- Perbarui layar pratinjau struk thermal di `PrintSheet` dengan visual efek kertas fisik.

### Fase 5: Verifikasi Aksesibilitas, Dark Mode & Full Regression Test
- Uji keterbacaan pada ukuran layar kecil ($360\text{dp}$) dan orientasi landscape.
- Jalankan `flutter analyze` dan seluruh test suite `flutter test` untuk menjamin nol regresi pada logika transaksi, database, dan pencetakan.

---

*Dokumen ini merupakan acuan resmi pengembangan antarmuka (UI) dan alur kerja (UX) NotaKit versi modern.*
