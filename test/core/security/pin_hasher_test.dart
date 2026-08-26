import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/security/pin_hasher.dart';

void main() {
  test('hash is deterministic for same pin+salt', () async {
    final salt = PinHasher.newSalt();
    final a = await PinHasher.hash('123456', salt);
    final b = await PinHasher.hash('123456', salt);
    expect(a, b);
  });

  test('different salts yield different hashes', () async {
    final h1 = await PinHasher.hash('123456', PinHasher.newSalt());
    final h2 = await PinHasher.hash('123456', PinHasher.newSalt());
    expect(h1, isNot(h2));
  });

  test('verifyPin accepts correct pin and rejects wrong pin', () async {
    final salt = PinHasher.newSalt();
    final hash = await PinHasher.hash('987654', salt);
    expect(await verifyPin(pin: '987654', saltHex: salt, expectedHashHex: hash), isTrue);
    expect(await verifyPin(pin: '123456', saltHex: salt, expectedHashHex: hash), isFalse);
  });

  test('salt length is 16 bytes (32 hex chars)', () {
    expect(PinHasher.newSalt().length, 32);
  });
}
