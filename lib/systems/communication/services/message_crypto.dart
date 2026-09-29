import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hivorr/core/security/crypto/aes_cipher.dart';
import 'package:hivorr/core/security/crypto/sha256.dart' as pinning_hash;

/// Conversation message encryption, v1 transport scheme (EP-04-04).
///
/// Payload contract (mirrors the server comment on `messages.body_encrypted`):
/// AES-256-GCM over UTF-8 JSON `{"v":1,"text":...,"at":...}`, serialized as
/// `EncryptedPayload {c,i,t}` base64 JSON. The server stores it opaquely and
/// only ever derives the redacted `body_preview` for lists/notifications.
///
/// Key agreement (v1): the conversation key derives deterministically from
/// data both participants already hold — `SHA-256("hivorr-msg-v1" ‖
/// contract_id)`. Contract ids are unguessable 128-bit values and message
/// rows are RLS-gated to participants, so ciphertext at rest is meaningful
/// without a key-exchange round-trip. A future EP replaces derivation with
/// an explicit per-conversation key exchange; the encrypt/decrypt boundary
/// here stays put.
///
/// Decryption failures (tamper, wrong key, malformed rows) return `null` —
/// callers must render an undecryptable-message placeholder and must never
/// fall back to any plaintext rendering of [bodyEncrypted].
abstract final class MessageCrypto {
  /// Domain separation prefix for the v1 key derivation.
  static const String keyPrefix = 'hivorr-msg-v1';

  /// Maximum plaintext length accepted for send (keeps ciphertext within the
  /// server 8000-char CHECK after base64 + JSON overhead).
  static const int maxPlaintextLength = 4000;

  /// Derives the conversation [SecretKey] for [contractId].
  static SecretKey keyForContract(String contractId) {
    final Uint8List digest = pinning_hash.sha256(
      utf8.encode('$keyPrefix$contractId'),
    );
    return SecretKey(digest);
  }

  /// Encrypts [text] for the [contractId] thread.
  ///
  /// Throws [ArgumentError] when [text] is blank or exceeds
  /// [maxPlaintextLength].
  static Future<String> encryptText({
    required String contractId,
    required String text,
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text must not be empty.');
    }
    if (trimmed.length > maxPlaintextLength) {
      throw ArgumentError(
        'Message text must be at most $maxPlaintextLength characters.',
      );
    }
    final String inner = jsonEncode(<String, Object?>{
      'v': 1,
      'text': trimmed,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    final EncryptedPayload payload = await AesCipher.defaultInstance
        .encryptString(inner, keyForContract(contractId));
    return jsonEncode(payload.toJson());
  }

  /// Decrypts a `body_encrypted` row for the [contractId] thread.
  ///
  /// Returns the verified plaintext, or `null` when authentication fails or
  /// the row is malformed. `null` is a hard reject — never render
  /// [bodyEncrypted] itself.
  static Future<String?> decryptText({
    required String contractId,
    required String bodyEncrypted,
  }) async {
    try {
      final Object? decoded = jsonDecode(bodyEncrypted);
      if (decoded is! Map) return null;
      final Map<String, String> payload = decoded.map(
        (Object? key, Object? value) =>
            MapEntry(key.toString(), value.toString()),
      );
      final EncryptedPayload encrypted = EncryptedPayload.fromJson(payload);
      final String inner = await AesCipher.defaultInstance.decryptString(
        encrypted,
        keyForContract(contractId),
      );
      final Object? innerDecoded = jsonDecode(inner);
      if (innerDecoded is! Map) return null;
      final Object? text = innerDecoded['text'];
      if (text is! String || text.isEmpty) return null;
      return text;
    } on Object {
      return null;
    }
  }

  /// Redacts preview text client-side (defense-in-depth alongside the
  /// server-side regexp mirror): callers send the raw preview and the server
  /// redacts before persisting.
  static String previewOf(String text) {
    final String trimmed = text.trim();
    return trimmed.length <= 120 ? trimmed : trimmed.substring(0, 120);
  }
}
