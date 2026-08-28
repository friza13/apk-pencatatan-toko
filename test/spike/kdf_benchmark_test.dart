import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Host-side benchmark for the backup KDF (D-004).
///
/// Runs PBKDF2-HMAC-SHA256 at candidate iteration counts and prints timings.
/// The final iteration count is chosen from these numbers plus a device
/// slowdown factor and recorded in docs/SPIKE_REPORT.md + AI_DECISION_LOG.
void main() {
  test('PBKDF2-HMAC-SHA256 benchmark across candidate iterations', () async {
    const password = 'correct horse battery staple';
    final salt = Uint8List.fromList(List<int>.filled(16, 7));

    // ignore: avoid_print
    print('[SPIKE-KDF] PBKDF2-HMAC-SHA256 timings (host, debug VM):');

    for (final iterations in const [100000, 200000, 400000, 600000, 800000]) {
      final algo = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

      final sw = Stopwatch()..start();
      final key = await algo.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      sw.stop();

      final bytes = await key.extractBytes();
      expect(bytes, hasLength(32));

      // ignore: avoid_print
      print(
        '[SPIKE-KDF] iterations=$iterations '
        '-> ${sw.elapsedMilliseconds} ms',
      );
    }
  });
}
