/// Typed exception for network management operations.
///
/// Normalizes network layer failures into a single surface so consumers
/// never see raw platform internals. No stored values, secrets, or device
/// identifiers are embedded in the message (EP-01-13 §12).
class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
