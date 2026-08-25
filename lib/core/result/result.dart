import '../error/failures.dart';

/// Typed result for use cases (SRS §20): Success(data) | Failure(Failure).
///
/// Domain and application layers return [Result] instead of throwing for
/// expected business failures; unexpected exceptions may still propagate.
sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;

  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is FailureResult<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        _ => null,
      };

  Failure? get failureOrNull => switch (this) {
        FailureResult<T>(:final failure) => failure,
        _ => null,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) =>
      switch (this) {
        Success<T>(:final data) => success(data),
        FailureResult<T>(failure: final err) => failure(err),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  String toString() => 'Success($data)';
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureResult($failure)';
}
