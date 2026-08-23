import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// An AES-GCM encrypted payload.
///
/// AES-GCM is a non-deterministic, authenticated cipher, so the nonce (IV) and
/// authentication tag are stored alongside the ciphertext. Serialize with
/// [toJson] before persisting the blob to [SecureStorage].
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    required this.tag,
  });

  /// The raw ciphertext bytes.
  final Uint8List ciphertext;

  /// The per-encryption nonce (IV).
  final Uint8List iv;

  /// The GCM authentication tag.
  final Uint8List tag;

  /// Serializes to a JSON-safe map (base64-encoded bytes).
  Map<String, String> toJson() {
    return <String, String>{
      'c': base64Encode(ciphertext),
      'i': base64Encode(iv),
      't': base64Encode(tag),
    };
  }

  /// Reconstructs a payload from a map produced by [toJson].
  factory EncryptedPayload.fromJson(Map<String, String> json) {
    return EncryptedPayload(
      ciphertext: base64Decode(json['c']!),
      iv: base64Decode(json['i']!),
      tag: base64Decode(json['t']!),
    );
  }
}

/// AES-256-GCM encryption utility for at-rest protection of sensitive client
/// blobs (e.g. refresh tokens, device secrets) before they are handed to
/// [SecureStorage] (EP-01-10 §5.3).
///
/// Defense-in-depth: on platforms where [flutter_secure_storage] is not
/// OS-encrypted (notably Web/localStorage), this layer prevents plaintext
/// token extraction. The key is supplied by the caller (typically derived via
/// [KeyDerivation]) and is never persisted by this class.
class AesCipher {
  AesCipher(this._algorithm);

  final AesGcm _algorithm;

  /// Default AES-256-GCM instance.
  static final AesCipher defaultInstance = AesCipher(AesGcm.with256bits());

  /// Encrypts [plaintext] with [key], returning a fresh [EncryptedPayload].
  ///
  /// A unique nonce is generated per call, so identical plaintexts yield
  /// different ciphertexts.
  Future<EncryptedPayload> encrypt(Uint8List plaintext, SecretKey key) async {
    final SecretBox secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: key,
    );
    return EncryptedPayload(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      iv: Uint8List.fromList(secretBox.nonce),
      tag: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  /// Convenience overload that encrypts a UTF-8 [plaintext] string.
  Future<EncryptedPayload> encryptString(String plaintext, SecretKey key) {
    return encrypt(Uint8List.fromList(utf8.encode(plaintext)), key);
  }

  /// Decrypts [payload] with [key].
  ///
  /// Throws when the authentication tag does not verify — i.e. tampered or
  /// incorrectly-keyed ciphertext. Callers must treat that as a hard reject
  /// and must never fall back to plaintext.
  Future<List<int>> decrypt(EncryptedPayload payload, SecretKey key) async {
    final SecretBox secretBox = SecretBox(
      payload.ciphertext,
      nonce: payload.iv,
      mac: Mac(payload.tag),
    );
    return _algorithm.decrypt(secretBox, secretKey: key);
  }

  /// Convenience overload that decrypts and returns a UTF-8 string.
  Future<String> decryptString(EncryptedPayload payload, SecretKey key) async {
    final List<int> bytes = await decrypt(payload, key);
    return utf8.decode(bytes);
  }
}
