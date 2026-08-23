import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/core/security/crypto/aes_cipher.dart';
import 'package:hivorr/core/security/crypto/key_derivation.dart';
import 'package:hivorr/core/security/security_config.dart';

void main() {
  group('AesCipher', () {
    final AesCipher cipher = AesCipher.defaultInstance;

    Future<SecretKey> deriveKey() async {
      final KeyDerivation kdf = KeyDerivation.fromConfiguration(
        _config(),
      );
      return kdf.deriveKey('passphrase');
    }

    test('round-trips a UTF-8 string', () async {
      final SecretKey key = await deriveKey();
      final EncryptedPayload payload =
          await cipher.encryptString('hunter2-secret', key);
      final String decrypted = await cipher.decryptString(payload, key);

      expect(decrypted, 'hunter2-secret');
    });

    test('round-trips raw bytes', () async {
      final SecretKey key = await deriveKey();
      final Uint8List plaintext = Uint8List.fromList(<int>[
        0,
        1,
        2,
        255,
        254,
        253,
      ]);
      final EncryptedPayload payload = await cipher.encrypt(plaintext, key);
      final List<int> decrypted = await cipher.decrypt(payload, key);

      expect(decrypted, plaintext);
    });

    test('produces a different ciphertext each call (random nonce)', () async {
      final SecretKey key = await deriveKey();
      final EncryptedPayload a = await cipher.encryptString('same', key);
      final EncryptedPayload b = await cipher.encryptString('same', key);

      expect(a.ciphertext, isNot(equals(b.ciphertext)));
      expect(a.iv, isNot(equals(b.iv)));
    });

    test('fails closed on tampered ciphertext', () async {
      final SecretKey key = await deriveKey();
      final EncryptedPayload payload =
          await cipher.encryptString('integrity', key);
      final Uint8List tampered = Uint8List.fromList(payload.ciphertext)
        ..[0] ^= 0x01;

      expect(
        () => cipher.decryptString(
          EncryptedPayload(
            ciphertext: tampered,
            iv: payload.iv,
            tag: payload.tag,
          ),
          key,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('fails closed with the wrong key', () async {
      final SecretKey key = await deriveKey();
      final SecretKey other = await KeyDerivation.fromConfiguration(
        _config(),
      ).deriveKey('different-passphrase');

      final EncryptedPayload payload =
          await cipher.encryptString('secret', key);

      expect(
        () => cipher.decryptString(payload, other),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}

SecurityConfiguration _config() => SecurityConfiguration(
      const SecurityConfig(
        pinningEnabled: false,
        pinnedSpkiSha256Hashes: <String>[],
        kdfSalt: 'salt',
        kdfIterations: 1000,
        kdfKeyLength: 32,
      ),
    );
