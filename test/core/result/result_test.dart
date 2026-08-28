import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/error/failures.dart';
import 'package:notakit/core/result/result.dart';

void main() {
  group('Result', () {
    test('success holds value', () {
      final Result<int> r = Result.success(7);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.dataOrNull, 7);
      expect(r.failureOrNull, isNull);
    });

    test('failure holds code and message', () {
      const Result<int> r = Result.failure(
        Failure(code: ErrorCodes.invalidPin, message: 'PIN salah'),
      );
      expect(r.isSuccess, isFalse);
      expect(r.isFailure, isTrue);
      expect(r.dataOrNull, isNull);
      expect(r.failureOrNull?.code, 'INVALID_PIN');
      expect(r.failureOrNull?.message, 'PIN salah');
    });

    test('when maps both branches', () {
      String describe(Result<int> r) =>
          r.when(success: (v) => 'ok $v', failure: (f) => 'err ${f.code}');

      expect(describe(Result.success(1)), 'ok 1');
      expect(
        describe(const Result.failure(Failure(code: 'X', message: 'boom'))),
        'err X',
      );
    });

    test('failure equality by code and message', () {
      const Failure a = Failure(code: 'A', message: 'm');
      const Failure b = Failure(code: 'A', message: 'm');
      const Failure c = Failure(code: 'B', message: 'm');
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });
}
