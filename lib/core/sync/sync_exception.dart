/// Typed exception for offline sync engine failures.
///
/// Normalizes sync operation failures into a single surface so consumers never
/// see raw driver or transport internals. No stored values, payloads, or
/// secrets are embedded in the message (EP-01-12 §12).
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => 'SyncException: $message';
}
