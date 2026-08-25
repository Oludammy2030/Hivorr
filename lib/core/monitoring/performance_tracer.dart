import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Performance tracing helpers backed by Sentry transactions and spans.
///
/// All operations are no-ops when [MonitoringConfig.isSentryActive] is `false`
/// OR [FeatureFlags.enableAnalyticsTracking] is `false`, so tracing never runs
/// unless explicitly enabled per environment (EP-01-14 §5.14).
class PerformanceTracer {
  PerformanceTracer(this._config, this._flags);

  final MonitoringConfig _config;
  final FeatureFlags _flags;

  /// Whether tracing is active.
  bool get isEnabled =>
      _config.isSentryActive && _flags.enableAnalyticsTracking;

  /// Starts a Sentry transaction; returns `null` when disabled.
  ISentrySpan? startTransaction(String name, String operation) {
    if (!isEnabled) return null;
    return Sentry.startTransaction(name, operation);
  }

  /// Creates a child span under [parent].
  ISentrySpan startChildSpan(
    ISentrySpan parent,
    String description,
    String operation,
  ) => parent.startChild(operation, description: description);

  /// Finishes [span] with the given [status]. Null spans are ignored.
  Future<void> finishSpan(ISentrySpan? span, {SpanStatus? status}) async {
    if (span == null) return;
    await span.finish(status: status ?? SpanStatus.ok());
  }
}
