import 'dart:async';

import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Log sink that routes entries to Sentry.
///
/// `debug`/`info`/`warning` become breadcrumbs; `error`/`fatal` become events
/// via [Sentry.captureException] (when an error is present) or
/// [Sentry.captureMessage]. Every entry additionally leaves a breadcrumb so
/// error events have a contextual trail (EP-01-14 §5.8).
class SentryLogSink implements LogSink {
  const SentryLogSink();

  @override
  void write(LogEntry entry) {
    final data = entry.context.isEmpty
        ? null
        : Map<String, dynamic>.from(entry.context);
    switch (entry.level) {
      case LogLevel.debug:
      case LogLevel.info:
      case LogLevel.warning:
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: entry.message,
              category: entry.loggerName,
              data: data,
              level: _toSentryLevel(entry.level),
              timestamp: entry.timestamp,
            ),
          ),
        );
      case LogLevel.error:
      case LogLevel.fatal:
        if (entry.error != null) {
          unawaited(
            Sentry.captureException(entry.error, stackTrace: entry.stackTrace),
          );
        } else {
          unawaited(
            Sentry.captureMessage(
              entry.message,
              level: _toSentryLevel(entry.level),
            ),
          );
        }
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: entry.message,
              category: entry.loggerName,
              data: data,
              level: _toSentryLevel(entry.level),
              timestamp: entry.timestamp,
            ),
          ),
        );
    }
  }

  static SentryLevel _toSentryLevel(LogLevel level) => switch (level) {
        LogLevel.debug => SentryLevel.debug,
        LogLevel.info => SentryLevel.info,
        LogLevel.warning => SentryLevel.warning,
        LogLevel.error => SentryLevel.error,
        LogLevel.fatal => SentryLevel.fatal,
      };

  @override
  void dispose() {}
}
