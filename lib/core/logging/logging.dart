import 'package:hivorr/core/logging/developer_log_sink.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/logging/sentry_log_sink.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';

export 'package:hivorr/core/logging/developer_log_sink.dart';
export 'package:hivorr/core/logging/hivorr_logger.dart';
export 'package:hivorr/core/logging/log_entry.dart';
export 'package:hivorr/core/logging/log_level.dart';
export 'package:hivorr/core/logging/log_router.dart';
export 'package:hivorr/core/logging/log_sink.dart';
export 'package:hivorr/core/logging/pii_redactor.dart';
export 'package:hivorr/core/logging/sentry_api_log_sink.dart';
export 'package:hivorr/core/logging/sentry_log_sink.dart';

/// Aggregate of the wired logging layer, returned by [initializeLogging].
class LoggingLayer {
  const LoggingLayer({
    required this.loggerFactory,
    required this.router,
    required this.redactor,
    required this.config,
  });

  /// Creates named, scoped loggers.
  final LoggerFactory loggerFactory;

  /// Active log routing.
  final LogRouter router;

  /// PII redaction utility.
  final PiiRedactor redactor;

  /// Active logging configuration.
  final MonitoringConfig config;
}

/// Constructs the logging layer from [MonitoringConfig].
///
/// - Builds a [PiiRedactor] honoring [MonitoringConfig.enablePiiRedaction].
/// - Routes to [SentryLogSink] when Sentry is active, otherwise
///   [DeveloperLogSink] (Development fallback).
/// - Derives the minimum level threshold from [MonitoringConfig.minimumLogLevel].
///
/// EP-01-15 bootstrap calls this at startup (EP-01-14 §5.16).
LoggingLayer initializeLogging(MonitoringConfig config) {
  final redactor = PiiRedactor(enabled: config.enablePiiRedaction);
  final minimumLevel = config.minimumLevel;
  final sinks = <LogSink>[
    if (config.isSentryActive)
      const SentryLogSink()
    else
      const DeveloperLogSink(),
  ];
  final router = LogRouter(sinks: sinks, minimumLevel: minimumLevel);
  final loggerFactory = LoggerFactory(router, redactor);
  return LoggingLayer(
    loggerFactory: loggerFactory,
    router: router,
    redactor: redactor,
    config: config,
  );
}
