import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';

/// Named-scope structured logger with automatic PII redaction.
///
/// Every `debug`/`info`/`warning`/`error`/`fatal` call redacts the message and
/// context through [PiiRedactor] before constructing a [LogEntry] and handing
/// it to the [LogRouter] (EP-01-14 §5.10).
class HivorrLogger {
  HivorrLogger(this._name, this._router, this._redactor);

  final String _name;
  final LogRouter _router;
  final PiiRedactor _redactor;

  /// Logs at [LogLevel.debug].
  void debug(String message, [Map<String, Object?>? context]) =>
      _log(LogLevel.debug, message, context: context);

  /// Logs at [LogLevel.info].
  void info(String message, [Map<String, Object?>? context]) =>
      _log(LogLevel.info, message, context: context);

  /// Logs at [LogLevel.warning].
  void warning(String message, [Map<String, Object?>? context]) =>
      _log(LogLevel.warning, message, context: context);

  /// Logs at [LogLevel.error] with optional error and stack trace.
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) =>
      _log(
        LogLevel.error,
        message,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );

  /// Logs at [LogLevel.fatal] with optional error and stack trace.
  void fatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) =>
      _log(
        LogLevel.fatal,
        message,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final redactedMessage = _redactor.redact(message);
    final redactedContext =
        context == null ? null : _redactor.redactContext(context);
    _router.write(
      LogEntry(
        level: level,
        message: redactedMessage,
        loggerName: _name,
        timestamp: DateTime.now(),
        context: redactedContext,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

/// Creates named [HivorrLogger] instances sharing the same router/redactor.
///
/// Subsystems obtain a scoped logger via `named('hivorr.sync')`,
/// `named('hivorr.api')`, etc. (EP-01-14 §5.10).
class LoggerFactory {
  LoggerFactory(this._router, this._redactor);

  final LogRouter _router;
  final PiiRedactor _redactor;

  /// Returns a [HivorrLogger] bound to [name].
  HivorrLogger named(String name) => HivorrLogger(name, _router, _redactor);
}
