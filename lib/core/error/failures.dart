/// Typed failure carrying a stable machine code from [ErrorCodes],
/// a human-readable message, and an optional underlying cause.
class Failure {
  const Failure({required this.code, required this.message, this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'Failure($code, $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Stable error codes (SRS §20). Never rely on message text for branching.
abstract final class ErrorCodes {
  static const authLocked = 'AUTH_LOCKED';
  static const invalidPin = 'INVALID_PIN';
  static const productNotFound = 'PRODUCT_NOT_FOUND';
  static const productInactive = 'PRODUCT_INACTIVE';
  static const stockInsufficient = 'STOCK_INSUFFICIENT';
  static const invalidQuantity = 'INVALID_QUANTITY';
  static const invalidDiscount = 'INVALID_DISCOUNT';
  static const invalidPayment = 'INVALID_PAYMENT';
  static const receivableLimitExceeded = 'RECEIVABLE_LIMIT_EXCEEDED';
  static const duplicateTransaction = 'DUPLICATE_TRANSACTION';
  static const backupInvalid = 'BACKUP_INVALID';
  static const backupWrongPassword = 'BACKUP_WRONG_PASSWORD';
  static const backupSchemaUnsupported = 'BACKUP_SCHEMA_UNSUPPORTED';
  static const backupCorrupted = 'BACKUP_CORRUPTED';
  static const marketplaceUnauthorized = 'MARKETPLACE_UNAUTHORIZED';
  static const marketplaceRateLimited = 'MARKETPLACE_RATE_LIMITED';
  static const marketplaceDuplicateOrder = 'MARKETPLACE_DUPLICATE_ORDER';
  static const printerNotFound = 'PRINTER_NOT_FOUND';
  static const printerConnectionFailed = 'PRINTER_CONNECTION_FAILED';
  static const databaseError = 'DATABASE_ERROR';
}
