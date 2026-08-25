import 'package:hivorr/core/logging/log_level.dart';

/// Immutable structured log record produced by [HivorrLogger].
///
/// Constructed only after PII redaction has been applied to the message and
/// context, so sinks receive redacted data exclusively (EP-01-14 §5.4).
class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    required this.loggerName,
    required this.timestamp,
    Map<String, Object?>? context,
    this.error,
    this.stackTrace,
  }) : context = context == null
           ? const <String, Object?>{}
           : Map.unmodifiable(context);

  /// Severity of the entry.
  final LogLevel level;

  /// Redacted log message.
  final String message;

  /// Named scope (e.g. `'hivorr.api'`, `'hivorr.sync'`).
  final String loggerName;

  /// When the entry was created.
  final DateTime timestamp;

  /// Redacted structured context fields.
  final Map<String, Object?> context;

  /// Optional error/exception object.
  final Object? error;

  /// Optional stack trace.
  final StackTrace? stackTrace;

  /// Whether this entry carries an error object.
  bool get hasError => error != null;
}
