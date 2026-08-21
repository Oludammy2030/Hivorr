import 'dart:developer' as developer;

/// Abstract sink for structured API-layer logs.
///
/// Decouples the logging interceptor from any concrete logging backend.
/// EP-01-14 will provide a Sentry-backed implementation; this layer only
/// defines the contract and a safe default (EP-01-07 §5.7).
abstract class ApiLogSink {
  const ApiLogSink();

  /// Emits a structured log entry.
  ///
  /// [level] is a short tag (e.g. `REQUEST`, `RESPONSE`, `ERROR`).
  /// [message] must never contain tokens, secrets, or config values.
  void log(String level, String message);
}

/// Default [ApiLogSink] backed by `dart:developer` logging.
///
/// Uses `developer.log` (not `print`) so it is permitted under the strict
/// production analyzer rules (EP-01-02/03).
class DeveloperLogSink extends ApiLogSink {
  const DeveloperLogSink(this.name);

  /// Logger name used to namespace API-layer output.
  final String name;

  @override
  void log(String level, String message) {
    developer.log(message, name: name);
  }
}
