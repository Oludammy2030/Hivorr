import 'package:hivorr/config/environments/app_environment.dart';

/// Transport-level configuration for the API layer.
///
/// Encapsulates timeouts and retry policy. Values are environment-tunable
/// but default to a single, conservative profile suitable for all
/// environments (EP-01-07 §5.3, §13).
class ApiConfig {
  const ApiConfig({
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
    required this.maxRetries,
    required this.baseRetryDelay,
    required this.maxRetryDelay,
  });

  /// Maximum time to establish a connection.
  final Duration connectTimeout;

  /// Maximum time to receive the full response.
  final Duration receiveTimeout;

  /// Maximum time to send the full request.
  final Duration sendTimeout;

  /// Maximum number of transient/5xx retry attempts.
  final int maxRetries;

  /// Base delay for exponential backoff.
  final Duration baseRetryDelay;

  /// Upper bound for a single backoff delay.
  final Duration maxRetryDelay;

  /// Returns the API configuration for the given [environment].
  ///
  /// A single conservative profile is used across environments; hooks remain
  /// for per-environment tuning without changing callers.
  static ApiConfig forEnvironment(AppEnvironment environment) {
    return ApiConfig(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      maxRetries: environment.isProduction ? 3 : 4,
      baseRetryDelay: const Duration(milliseconds: 500),
      maxRetryDelay: const Duration(seconds: 8),
    );
  }
}
