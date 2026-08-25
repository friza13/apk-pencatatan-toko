# NOTAKIT — Data Flow Diagram (DFD) & Core Workflows

# 11. Data Flow Diagram (DFD)

## 11.1 Context Diagram

```mermaid
flowchart TB
    OWNER[Owner / User]
    APP[NotaKit UMKM App]
    FILE[Backup File / External Storage]
    PRINTER[Printer]
    MARKET[Marketplace APIs]
    DRIVE[Optional Cloud Drive]

    OWNER -->|input transaksi, master, settings| APP
    APP -->|dashboard, laporan, notifikasi| OWNER
    APP -->|print/share| PRINTER
    OWNER -->|export/import| FILE
    APP -->|backup upload/download| DRIVE
    APP -->|import order/income| MARKET
    MARKET -->|order/status/income| APP
```

## 11.2 DFD Level 0

```mermaid
flowchart TB
    U[Owner]
    P1((1.0 Master Data))
    P2((2.0 Sales / Nota))
    P3((3.0 Inventory))
    P4((4.0 Finance & Receivable))
    P5((5.0 Reporting))
    P6((6.0 Backup & Restore))
    P7((7.0 Marketplace))
    P8((8.0 Printing & Sharing))
    P9((9.0 Settings & Security))

    D1[(Master DB)]
    D2[(Transaction DB)]
    D3[(Ledger DB)]
    D4[(Activity Log)]
    D5[(Backup File)]

    U --> P1
    U --> P2
    U --> P3
    U --> P4
    U --> P5
    U --> P6
    U --> P7
    U --> P8
    U --> P9

    P1 <--> D1
    P2 <--> D2
    P2 --> P3
    P2 --> P4
    P3 <--> D2
    P4 <--> D3
    P5 --> D1
    P5 --> D2
    P5 --> D3
    P6 <--> D1
    P6 <--> D2
    P6 <--> D3
    P6 <--> D4
    P6 <--> D5
    P7 <--> D2
    P2 --> D4
    P3 --> D4
    P4 --> D4
    P6 --> D4
    P9 <--> D4
```

## 11.3 DFD Penjualan

```mermaid
flowchart LR
    U[Owner]
    S1((Create Sale))
    S2((Calculate Total))
    S3((Commit Transaction))
    D1[(Product DB)]
    D2[(Sale DB)]
    D3[(Stock Movement)]
    D4[(Payment / Ledger)]
    D5[(Audit Log)]

    U -->|cart items| S1
    S1 -->|read price/stock| D1
    S1 --> S2
    S2 -->|gross discount tax total| S3
    S3 --> D2
    S3 --> D3
    S3 --> D4
    S3 --> D5
    S3 -->|success| U
```

## 11.4 DFD Backup

```mermaid
flowchart TB
    U[Owner]
    B1((Create Backup))
    B2((Serialize))
    B3((Compress))
    B4((Encrypt))
    B5((Hash / Manifest))
    F[(Backup File)]
    DB[(SQLite DB)]
    FS[(Media Files)]

    U --> B1
    DB --> B1
    FS --> B1
    B1 --> B2 --> B3 --> B4 --> B5 --> F

    F -->|import| R1((Validate))
    R1 --> R2((Decrypt))
    R2 --> R3((Verify Schema + Integrity))
    R3 --> R4((Restore Temp DB))
    R4 --> R5((Atomic Swap))
    R5 --> U
```

---

# 12. Core Workflow

## 12.1 Penjualan Normal

```text
Open App
 -> Unlock
 -> New Sale
 -> Select Customer (optional)
 -> Scan/Search Product
 -> Select Unit/Variant
 -> Set Qty
 -> Apply Price Tier
 -> Apply Discount
 -> Apply Tax/Service Fee
 -> Payment
 -> Finalize
 -> Atomic commit
    -> Sale saved
    -> Stock movement created
    -> Payment ledger created
    -> Receivable created if needed
    -> Activity log created
 -> Print/Share
```

## 12.2 Pindah HP

```text
HP Lama
  -> Settings
  -> Backup / Export
  -> Full Backup
  -> Encrypt with password
  -> Generate .NotaKitbackup
  -> transfer via cable/Drive/Share

HP Baru
  -> Install app
  -> Import backup
  -> Enter password
  -> Validate
  -> Preview data counts
  -> Confirm restore
  -> Restore
  -> Rebuild indexes/cache
  -> Verify reports
```

---
