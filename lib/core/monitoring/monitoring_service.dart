import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Wraps Sentry SDK operations with PII-safe, environment-gated abstractions.
///
/// Every method is a no-op when [MonitoringConfig.isSentryActive] is `false`,
/// so callers may invoke them unconditionally in any environment (EP-01-14
/// §5.12, §12).
class MonitoringService {
  MonitoringService(this._config, {PiiRedactor? redactor})
      : _redactor = redactor ?? PiiRedactor(enabled: _config.enablePiiRedaction);

  final MonitoringConfig _config;
  final PiiRedactor _redactor;

  /// Whether Sentry capture is active.
  bool get isEnabled => _config.isSentryActive;

  /// Reports an exception to Sentry, attaching redacted structured context.
  Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) async {
    if (!isEnabled) return;
    if (context != null && context.isNotEmpty) {
      await _recordContextBreadcrumb(context);
    }
    await Sentry.captureException(error, stackTrace: stackTrace);
  }

  /// Reports a message to Sentry at the given [level].
  Future<void> captureMessage(
    String message, {
    LogLevel? level,
    Map<String, Object?>? context,
  }) async {
    if (!isEnabled) return;
    final redactedMessage = _redactor.redact(message);
    if (context != null && context.isNotEmpty) {
      await _recordContextBreadcrumb(context);
    }
    await Sentry.captureMessage(redactedMessage, level: _toSentryLevel(level));
  }

  /// Adds a PII-redacted breadcrumb to the current scope.
  Future<void> addBreadcrumb(
    String category,
    String message, {
    Map<String, Object?>? data,
  }) async {
    if (!isEnabled) return;
    final redactedData =
        data == null ? null : _redactor.redactContext(data);
    await Sentry.addBreadcrumb(
      Breadcrumb(
        category: category,
        message: _redactor.redact(message),
        data: redactedData == null
            ? null
            : Map<String, dynamic>.from(redactedData),
      ),
    );
  }

  /// Sets Sentry user context to the entity ID only (no PII).
  ///
  /// Pass `null` to clear the context.
  Future<void> setUserContext(String? entityId) async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) async {
      await scope.setUser(entityId == null ? null : SentryUser(id: entityId));
    });
  }

  /// Clears Sentry user context (e.g. on logout).
  Future<void> clearUserContext() async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) async {
      await scope.setUser(null);
    });
  }

  /// Sets a Sentry tag.
  Future<void> setTag(String key, String value) async {
    if (!isEnabled) return;
    await Sentry.configureScope((scope) async {
      await scope.setTag(key, value);
    });
  }

  Future<void> _recordContextBreadcrumb(Map<String, Object?> context) async {
    final redacted = _redactor.redactContext(context);
    await Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'context',
        message: 'structured context',
        data: Map<String, dynamic>.from(redacted),
      ),
    );
  }

  static SentryLevel? _toSentryLevel(LogLevel? level) {
    if (level == null) return null;
    return switch (level) {
      LogLevel.debug => SentryLevel.debug,
      LogLevel.info => SentryLevel.info,
      LogLevel.warning => SentryLevel.warning,
      LogLevel.error => SentryLevel.error,
      LogLevel.fatal => SentryLevel.fatal,
    };
  }
}
