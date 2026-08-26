import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/security/pin_hasher.dart';

void main() {
  const hasher = PinHasher(iterations: 1000);

  test('hash is deterministic for same pin+salt', () async {
    final salt = hasher.newSalt();
    final a = await hasher.hash('123456', salt);
    final b = await hasher.hash('123456', salt);
    expect(a, b);
  });

  test('different salts yield different hashes', () async {
    final h1 = await hasher.hash('123456', hasher.newSalt());
    final h2 = await hasher.hash('123456', hasher.newSalt());
    expect(h1, isNot(h2));
  });

  test('verifyPinHash accepts correct pin and rejects wrong pin', () async {
    final salt = hasher.newSalt();
    final hash = await hasher.hash('987654', salt);
    expect(
      await verifyPinHash(
        hasher: hasher,
        pin: '987654',
        saltHex: salt,
        expectedHashHex: hash,
      ),
      isTrue,
    );
    expect(
      await verifyPinHash(
        hasher: hasher,
        pin: '123456',
        saltHex: salt,
        expectedHashHex: hash,
      ),
      isFalse,
    );
  });

  test('salt length is 16 bytes (32 hex chars)', () {
    expect(hasher.newSalt().length, 32);
  });
}
