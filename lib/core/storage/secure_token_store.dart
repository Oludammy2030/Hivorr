import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'package:hivorr/core/security/crypto/aes_cipher.dart';

import 'secure_storage.dart';

/// Typed, high-level store for the client's opaque auth secrets.
///
/// Holds only non-interpreted token material (access/refresh tokens, session
/// id, device secret). Never derives or applies authorization from these
/// values (AGENT.md Rule 4). Backed by [SecureStorage] (EP-01-10 §5.6).
///
/// When an [AesCipher] and [deriveKey] are supplied, the access/refresh tokens
/// and session id are encrypted at rest (AES-GCM, unique nonce per write)
/// before being handed to [SecureStorage]; reads transparently decrypt. The
/// device secret is intentionally stored in the clear because it is the
/// key source itself. Encryption is opt-in so the store remains usable without
/// a key (e.g. before EP-01-09 provisions one) — existing plaintext callers
/// are unaffected (EP-01-10 §5.6, §12 R3).
class SecureTokenStore {
  const SecureTokenStore(this.storage, {this.cipher, this.deriveKey});

  /// The platform secure-storage backend.
  final SecureStorage storage;

  /// AES-GCM cipher used for at-rest encryption of token material.
  final AesCipher? cipher;

  /// Resolves the [SecretKey] used to encrypt/decrypt token material. Supplied
  /// by the integrating layer (EP-01-09), typically derived from a device secret
  /// persisted in this same store.
  final Future<SecretKey> Function()? deriveKey;

  /// Whether token material is encrypted at rest.
  bool get isEncrypted => cipher != null && deriveKey != null;

  static const String _accessKey = 'auth.access_token';
  static const String _refreshKey = 'auth.refresh_token';
  static const String _sessionIdKey = 'auth.session_id';
  static const String _deviceSecretKey = 'device.secret';

  /// Persists the access token (encrypted when [isEncrypted]).
  Future<void> writeAccessToken(String token) => _write(_accessKey, token);

  /// Reads the persisted access token (decrypted when [isEncrypted]).
  Future<String?> readAccessToken() => _read(_accessKey);

  /// Persists the refresh token (encrypted when [isEncrypted]).
  Future<void> writeRefreshToken(String token) => _write(_refreshKey, token);

  /// Reads the persisted refresh token.
  Future<String?> readRefreshToken() => _read(_refreshKey);

  /// Persists the session id (encrypted when [isEncrypted]).
  Future<void> writeSessionId(String id) => _write(_sessionIdKey, id);

  /// Reads the persisted session id.
  Future<String?> readSessionId() => _read(_sessionIdKey);

  /// Persists a device-bound secret (e.g. the AES passphrase seed). Stored in
  /// the clear — it is the key source and must remain readable to derive keys.
  Future<void> writeDeviceSecret(String secret) =>
      storage.writeString(_deviceSecretKey, secret);

  /// Reads the persisted device secret.
  Future<String?> readDeviceSecret() => storage.readString(_deviceSecretKey);

  /// Clears the auth tokens/session (device secret is retained).
  Future<void> clearTokens() async {
    await storage.delete(_accessKey);
    await storage.delete(_refreshKey);
    await storage.delete(_sessionIdKey);
  }

  Future<String?> _read(String key) async {
    final String? raw = await storage.readString(key);
    if (raw == null || !isEncrypted) {
      return raw;
    }
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    final EncryptedPayload payload = EncryptedPayload.fromJson(<String, String>{
      'c': json['c'] as String,
      'i': json['i'] as String,
      't': json['t'] as String,
    });
    return cipher!.decryptString(payload, await deriveKey!());
  }

  Future<void> _write(String key, String value) async {
    if (!isEncrypted) {
      await storage.writeString(key, value);
      return;
    }
    final EncryptedPayload payload = await cipher!.encryptString(
      value,
      await deriveKey!(),
    );
    await storage.writeString(key, jsonEncode(payload.toJson()));
  }
}
