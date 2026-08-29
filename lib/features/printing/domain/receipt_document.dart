import 'receipt_config.dart';

/// Represents a single line item on a receipt slip.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.qty,
    this.unit,
    int? unitPriceMinor,
    int? priceMinor,
    int? lineTotalMinor,
    int? totalMinor,
    this.discountMinor = 0,
  })  : unitPriceMinor = unitPriceMinor ?? priceMinor ?? 0,
        lineTotalMinor = lineTotalMinor ?? totalMinor ?? 0;

  final String name;
  final String qty;
  final String? unit;
  final int unitPriceMinor;
  final int lineTotalMinor;
  final int discountMinor;

  /// Alias for unitPriceMinor for backward compatibility.
  int get priceMinor => unitPriceMinor;

  /// Alias for lineTotalMinor for backward compatibility.
  int get totalMinor => lineTotalMinor;
}

/// Backwards-compatibility alias for [ReceiptItem].
typedef ReceiptLine = ReceiptItem;

/// Canonical receipt document model containing all presentation and business
/// fields needed to render thermal receipts, ESC/POS, and high-res PDFs.
class ReceiptDocument {
  const ReceiptDocument({
    required this.storeName,
    this.tagline,
    this.transactionId,
    required this.invoiceNumber,
    required this.dateTimeLocal,
    this.customerName,
    this.operatorName,
    required this.lines,
    required this.subtotalMinor,
    this.discountMinor = 0,
    this.taxMinor = 0,
    this.shippingMinor = 0,
    this.roundingMinor = 0,
    required this.grandTotalMinor,
    required this.paidMinor,
    this.dueMinor = 0,
    this.changeMinor = 0,
    required this.paymentLabel,
    this.footerNote,
    this.totalItemCount,
    this.currencySymbol = 'Rp',
    this.config = const ReceiptConfig(),
  });

  final String storeName;
  final String? tagline;
  final String? transactionId;
  final String invoiceNumber;
  final String dateTimeLocal;
  final String? customerName;
  final String? operatorName;
  final List<ReceiptItem> lines;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int shippingMinor;
  final int roundingMinor;
  final int grandTotalMinor;
  final int paidMinor;
  final int dueMinor;
  final int changeMinor;
  final String paymentLabel;
  final String? footerNote;
  final String? totalItemCount;
  final String currencySymbol;
  final ReceiptConfig config;

  /// Returns custom footer note if present; otherwise returns default config footer.
  String get effectiveFooter {
    if (footerNote != null && footerNote!.trim().isNotEmpty) {
      return footerNote!.trim();
    }
    return config.customFooter;
  }

  /// Returns explicit QR payload URL/string if configured; otherwise defaults
  /// to the receipt invoice number.
  String get effectiveQrPayload {
    if (config.qrPayload != null && config.qrPayload!.trim().isNotEmpty) {
      return config.qrPayload!.trim();
    }
    return invoiceNumber;
  }

  /// Calculates total item count sum from line quantities or returns [totalItemCount].
  String get calculatedItemCount {
    if (totalItemCount != null && totalItemCount!.trim().isNotEmpty) {
      return totalItemCount!.trim();
    }
    double sum = 0;
    for (final l in lines) {
      sum += double.tryParse(l.qty) ?? 1;
    }
    if (sum == sum.roundToDouble()) {
      return sum.toInt().toString();
    }
    final s = sum.toStringAsFixed(3);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }
}
