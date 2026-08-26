import '../../../core/error/failures.dart';

/// Result wrapper for finance/receivable mutations.
class FinanceResult {
  const FinanceResult.success() : failure = null;

  const FinanceResult.failure(this.failure);

  final Failure? failure;

  bool get isSuccess => failure == null;
}
