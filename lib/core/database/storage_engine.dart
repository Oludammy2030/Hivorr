/// A single mutation within a [StorageEngine.writeBatch] call.
///
/// Sealed so the engine can exhaustively handle every operation kind without
/// falling through to an unknown branch.
sealed class WriteOp {
  const WriteOp(this.key);

  /// The key affected by this operation.
  final String key;
}

/// Inserts or replaces [value] at [key].
final class PutOp extends WriteOp {
  const PutOp(super.key, this.value);

  /// The JSON-compatible value to store.
  final Map<String, dynamic> value;
}

/// Removes [key] from the box.
final class DeleteOp extends WriteOp {
  const DeleteOp(super.key);
}

/// Abstraction over a persistent, typed, crash-safe local store.
///
/// Concrete drivers (Hive, SQLite, Isar) implement this interface so the data
/// layer (EP-01-08) and the sync engine (EP-01-12) depend only on the contract
/// — never on a specific driver (vendor-lock-in mitigation, consistent with
/// EP-01-08).
///
/// Values are JSON-compatible `Map<String, dynamic>`; typed mapping (`T`
/// ↔ `Map`) is the consumer's responsibility (see [LocalStore]), keeping this
/// layer free of business/DTO logic (AGENT.md Rule 4).
///
/// No secrets or tokens are ever stored here — those belong to
/// `lib/core/storage/` (EP-01-10 `SecureStorage`).
abstract class StorageEngine {
  /// Stores [value] at [key] inside [box]. Overwrites any existing value.
  Future<void> put(String box, String key, Map<String, dynamic> value);

  /// Returns the value stored at [key] inside [box], or `null` if absent.
  Future<Map<String, dynamic>?> get(String box, String key);

  /// Removes [key] from [box]. No-op if the key is absent.
  Future<void> delete(String box, String key);

  /// Removes every entry in [box]. Other boxes are unaffected.
  Future<void> clearBox(String box);

  /// Returns all keys currently present in [box].
  Future<List<String>> keys(String box);

  /// Applies all [ops] to [box] as a best-effort atomic batch.
  ///
  /// Every operation is applied; if any fails, the engine restores the
  /// snapshot of affected keys taken before the batch, so a partial failure
  /// cannot leave the queue half-written (queue-safe for EP-01-12).
  Future<void> writeBatch(String box, List<WriteOp> ops);
}
