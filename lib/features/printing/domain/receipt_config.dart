/// Configuration options for receipt rendering across text, ESC/POS, and PDF.
class ReceiptConfig {
  const ReceiptConfig({
    this.showTagline = true,
    this.showOperator = true,
    this.showItemCount = true,
    this.showSignature = true,
    this.showQr = true,
    this.customFooter = 'TERIMA KASIH TELAH BELANJA DI KAMI',
    this.qrPayload,
  });

  /// Whether to display the store subtitle / tagline in the header.
  final bool showTagline;

  /// Whether to display the operator / cashier name in the metadata section.
  final bool showOperator;

  /// Whether to display the total item count in the summary totals section.
  final bool showItemCount;

  /// Whether to render a signature / stamp box at the footer.
  final bool showSignature;

  /// Whether to render a QR code (or QR placeholder in text).
  final bool showQr;

  /// Default footer thank-you message if no custom sale footer note is set.
  final String customFooter;

  /// Explicit QR payload URL or string (e.g. invoice verification link).
  /// If null, falls back to the invoice / sale number.
  final String? qrPayload;

  ReceiptConfig copyWith({
    bool? showTagline,
    bool? showOperator,
    bool? showItemCount,
    bool? showSignature,
    bool? showQr,
    String? customFooter,
    String? qrPayload,
  }) {
    return ReceiptConfig(
      showTagline: showTagline ?? this.showTagline,
      showOperator: showOperator ?? this.showOperator,
      showItemCount: showItemCount ?? this.showItemCount,
      showSignature: showSignature ?? this.showSignature,
      showQr: showQr ?? this.showQr,
      customFooter: customFooter ?? this.customFooter,
      qrPayload: qrPayload ?? this.qrPayload,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptConfig &&
          runtimeType == other.runtimeType &&
          showTagline == other.showTagline &&
          showOperator == other.showOperator &&
          showItemCount == other.showItemCount &&
          showSignature == other.showSignature &&
          showQr == other.showQr &&
          customFooter == other.customFooter &&
          qrPayload == other.qrPayload;

  @override
  int get hashCode => Object.hash(
    showTagline,
    showOperator,
    showItemCount,
    showSignature,
    showQr,
    customFooter,
    qrPayload,
  );
}
