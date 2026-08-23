/// Typed exception for local storage engine failures.
///
/// Normalizes driver-specific failures (Hive, SQLite, etc.) into a single
/// surface so consumers never see raw driver internals, SQL, or storage paths.
/// No stored values, keys, or secrets are embedded in the message.
class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}
