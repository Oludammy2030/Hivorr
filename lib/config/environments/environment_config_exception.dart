/// Safe, non-sensitive configuration validation exception.
///
/// This exception reports configuration failures without exposing any
/// configuration value. It identifies only the failing variable name and
/// a human-readable reason. It must never contain keys, URLs, tokens, or
/// any sensitive data.
///
/// Compliance with EP-01-03 §5.5 and §12:
/// - "Secret leakage through logs" — values are never included.
/// - "Malformed configuration" — failures are reported with actionable detail.
class EnvironmentConfigException implements Exception {
  /// Creates a safe configuration exception.
  ///
  /// [variableName] identifies the configuration variable that failed
  /// validation. [reason] describes the failure without exposing the value.
  const EnvironmentConfigException({
    required this.variableName,
    required this.reason,
  });

  /// The name of the configuration variable that failed validation.
  final String variableName;

  /// A human-readable description of the validation failure.
  ///
  /// This message must never contain the actual configuration value.
  final String reason;

  @override
  String toString() {
    return 'EnvironmentConfigException: $variableName — $reason';
  }
}
