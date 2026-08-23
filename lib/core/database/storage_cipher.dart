/// Optional at-rest encryption seam for [LocalStore].
///
/// When [DatabaseConfig.encryptAtRest] is enabled, [LocalStore] wraps each
/// stored JSON map through an implementation of this interface before handing
/// it to the [StorageEngine], and decrypts on read. This keeps the encryption
/// implementation out of EP-01-11 (the `AesCipher` lives in EP-01-10); EP-01-10
/// can satisfy this contract with a thin adapter, so the two modules stay
/// decoupled (plan §5.5).
///
/// Implementations must be deterministic per key and must never embed secrets
/// in exceptions.
abstract class StorageCipher {
  /// Encrypts a JSON-compatible [value] for persistence.
  Future<Map<String, dynamic>> encrypt(Map<String, dynamic> value);

  /// Decrypts a [stored] payload produced by [encrypt] back into a JSON map.
  Future<Map<String, dynamic>> decrypt(Map<String, dynamic> stored);
}
