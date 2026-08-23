import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:hivorr/core/security/security_config.dart';

/// Derives symmetric encryption keys from a passphrase using PBKDF2-HMAC-SHA256.
///
/// Turns a device-bound secret (or a random secret persisted in
/// [SecureStorage]) into an AES key without ever hardcoding key material
/// (EP-01-10 §5.3). All parameters are sourced from [SecurityConfiguration],
/// which reads them from the EP-01-03 [EnvironmentConfig].
class KeyDerivation {
  const KeyDerivation(
    this._algorithm,
    this.salt,
    this.iterations,
    this.keyLength,
  );

  final Pbkdf2 _algorithm;
  final String salt;
  final int iterations;
  final int keyLength;

  /// Builds a [KeyDerivation] from the resolved security configuration.
  factory KeyDerivation.fromConfiguration(SecurityConfiguration config) {
    final Pbkdf2 algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: config.kdfIterations,
      bits: config.kdfKeyLength * 8,
    );
    return KeyDerivation(
      algorithm,
      config.kdfSalt,
      config.kdfIterations,
      config.kdfKeyLength,
    );
  }

  /// Derives a [SecretKey] from [passphrase] using the configured salt.
  Future<SecretKey> deriveKey(String passphrase) {
    return _algorithm.deriveKeyFromPassword(
      password: passphrase,
      nonce: utf8.encode(salt),
    );
  }

  /// Generates a cryptographically random, URL-safe secret string suitable
  /// for use as the [passphrase] to [deriveKey] (then persisted in
  /// [SecureStorage]). Never hardcoded.
  static String generateRandomSecret({int length = 32}) {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }
}
