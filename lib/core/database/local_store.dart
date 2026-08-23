import 'package:hivorr/core/database/storage_cipher.dart';
import 'package:hivorr/core/database/storage_engine.dart';

/// Typed, high-level accessor over a [StorageEngine].
///
/// Consumers supply `toJson`/`fromJson` mapper functions so entity/DTO
/// serialization stays in the data layer (EP-01-08), not in this foundation
/// module. This keeps EP-01-11 free of business logic (AGENT.md Rule 4).
///
/// If a [cipher] is provided (when [DatabaseConfig.encryptAtRest] is enabled),
/// values are encrypted at rest before being handed to the engine. The default
/// is no cipher — the persistent store holds only non-secret operational data.
class LocalStore {
  LocalStore(this._engine, {this.cipher});

  final StorageEngine _engine;
  final StorageCipher? cipher;

  /// Reads [key] from [box] and maps it to `T` via [fromJson].
  ///
  /// Returns `null` when the key is absent.
  Future<T?> read<T>(
    String box,
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final Map<String, dynamic>? raw = await _engine.get(box, key);
    if (raw == null) {
      return null;
    }
    final Map<String, dynamic> json =
        cipher == null ? raw : await cipher!.decrypt(raw);
    return fromJson(json);
  }

  /// Serializes [value] via [toJson] and stores it at [key] in [box].
  Future<void> write<T>(
    String box,
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  ) async {
    final Map<String, dynamic> json = toJson(value);
    final Map<String, dynamic> stored =
        cipher == null ? json : await cipher!.encrypt(json);
    await _engine.put(box, key, stored);
  }

  /// Removes [key] from [box].
  Future<void> remove(String box, String key) => _engine.delete(box, key);

  /// Clears every entry in [box].
  Future<void> clearBox(String box) => _engine.clearBox(box);

  /// Returns all keys present in [box].
  Future<List<String>> keys(String box) => _engine.keys(box);

  /// Applies [ops] to [box] as a best-effort atomic batch.
  Future<void> writeBatch(String box, List<WriteOp> ops) =>
      _engine.writeBatch(box, ops);
}
