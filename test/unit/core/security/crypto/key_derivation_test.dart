import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/core/security/crypto/key_derivation.dart';
import 'package:hivorr/core/security/security_config.dart';

void main() {
  group('KeyDerivation', () {
    final SecurityConfiguration config = SecurityConfiguration(
      const SecurityConfig(
        pinningEnabled: false,
        pinnedSpkiSha256Hashes: <String>[],
        kdfSalt: 'static-salt',
        kdfIterations: 1000,
        kdfKeyLength: 32,
      ),
    );

    test('deriveKey is deterministic for the same inputs', () async {
      final KeyDerivation kdf = KeyDerivation.fromConfiguration(config);
      final List<int> a = await kdf.deriveKey('passphrase').then(_bytes);
      final List<int> b = await kdf.deriveKey('passphrase').then(_bytes);

      expect(a, b);
      expect(a.length, 32);
    });

    test('deriveKey differs when the passphrase differs', () async {
      final KeyDerivation kdf = KeyDerivation.fromConfiguration(config);
      final List<int> a = await kdf.deriveKey('passphrase').then(_bytes);
      final List<int> b = await kdf.deriveKey('other').then(_bytes);

      expect(a, isNot(equals(b)));
    });

    test('deriveKey differs when the salt differs', () async {
      final KeyDerivation kdf = KeyDerivation.fromConfiguration(config);
      final KeyDerivation other = KeyDerivation.fromConfiguration(
        SecurityConfiguration(
          const SecurityConfig(
            pinningEnabled: false,
            pinnedSpkiSha256Hashes: <String>[],
            kdfSalt: 'different-salt',
            kdfIterations: 1000,
            kdfKeyLength: 32,
          ),
        ),
      );
      final List<int> a = await kdf.deriveKey('passphrase').then(_bytes);
      final List<int> b = await other.deriveKey('passphrase').then(_bytes);

      expect(a, isNot(equals(b)));
    });

    test('respects the configured key length', () async {
      final KeyDerivation kdf = KeyDerivation.fromConfiguration(
        SecurityConfiguration(
          const SecurityConfig(
            pinningEnabled: false,
            pinnedSpkiSha256Hashes: <String>[],
            kdfSalt: 'salt',
            kdfIterations: 1000,
            kdfKeyLength: 16,
          ),
        ),
      );
      final List<int> bytes = await kdf.deriveKey('passphrase').then(_bytes);
      expect(bytes.length, 16);
    });

    test('generateRandomSecret produces unique URL-safe secrets', () {
      final String a = KeyDerivation.generateRandomSecret();
      final String b = KeyDerivation.generateRandomSecret();

      expect(a, isNot(equals(b)));
      expect(a.length, 44); // base64url of 32 bytes (no padding).
      expect(() => base64Url.decode(a), returnsNormally);
    });
  });
}

Future<List<int>> _bytes(SecretKey key) => key.extractBytes();
