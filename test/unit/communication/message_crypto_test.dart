import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/communication/services/message_crypto.dart';

void main() {
  group('MessageCrypto', () {
    test('encrypt/decrypt round-trips for the same contract', () async {
      const String contractId = '11111111-1111-4111-8111-111111111111';
      const String text = 'Hello, can you start on Monday? My number is here.';
      final String encrypted = await MessageCrypto.encryptText(
        contractId: contractId,
        text: text,
      );
      // Opaque ciphertext: no plaintext leakage, server CHECK-sized.
      expect(encrypted.contains('Monday'), isFalse);
      expect(encrypted.length, greaterThanOrEqualTo(20));
      expect(encrypted.length, lessThanOrEqualTo(8000));

      final String? decrypted = await MessageCrypto.decryptText(
        contractId: contractId,
        bodyEncrypted: encrypted,
      );
      expect(decrypted, text);
    });

    test('wrong contract key hard-rejects (null, never plaintext)', () async {
      const String contractA = 'aaaaaaaa-1111-4111-8111-111111111111';
      const String contractB = 'bbbbbbbb-2222-4222-8222-222222222222';
      final String encrypted = await MessageCrypto.encryptText(
        contractId: contractA,
        text: 'Secret work details.',
      );
      final String? decrypted = await MessageCrypto.decryptText(
        contractId: contractB,
        bodyEncrypted: encrypted,
      );
      expect(decrypted, isNull);
    });

    test('malformed rows hard-reject', () async {
      expect(
        await MessageCrypto.decryptText(
          contractId: 'c',
          bodyEncrypted: 'not-json-at-all',
        ),
        isNull,
      );
      expect(
        await MessageCrypto.decryptText(
          contractId: 'c',
          bodyEncrypted: '{"c":"@@@","i":"@@@","t":"@@@"}',
        ),
        isNull,
      );
    });

    test('blank and oversize text are rejected before transport', () async {
      expect(
        () => MessageCrypto.encryptText(contractId: 'c', text: '   '),
        throwsArgumentError,
      );
      expect(
        () => MessageCrypto.encryptText(
          contractId: 'c',
          text: 'x' * (MessageCrypto.maxPlaintextLength + 1),
        ),
        throwsArgumentError,
      );
    });

    test('preview truncates to 120 chars', () {
      expect(MessageCrypto.previewOf('short'), 'short');
      expect(MessageCrypto.previewOf('x' * 200), hasLength(120));
    });

    test('same text encrypts differently each call (random nonce)', () async {
      const String contractId = 'cccccccc-3333-4333-8333-333333333333';
      final String first = await MessageCrypto.encryptText(
        contractId: contractId,
        text: 'Same message twice.',
      );
      final String second = await MessageCrypto.encryptText(
        contractId: contractId,
        text: 'Same message twice.',
      );
      expect(first, isNot(second));
    });
  });
}
