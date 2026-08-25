import 'dart:developer' as developer;

import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_sink.dart';

/// Signature of the underlying log function used by [DeveloperLogSink].
typedef DevLogHandler =
    void Function(String message, {int level, String name, DateTime? time});

/// Log sink backed by `dart:developer` `developer.log()`.
///
/// Used in Development where Sentry is disabled. Never uses `print()` so it
/// complies with the strict production analyzer rules (EP-01-14 §5.7). The
/// [logHandler] is injectable to make the sink unit-testable without capturing
/// the VM service log stream.
class DeveloperLogSink implements LogSink {
  const DeveloperLogSink({
    this.name = 'hivorr',
    this.logHandler = developer.log,
  });

  /// Fallback logger name when an entry has no scope name.
  final String name;

  /// Underlying log function (defaults to `developer.log`).
  final DevLogHandler logHandler;

  @override
  void write(LogEntry entry) {
    final buffer = StringBuffer()
      ..write('[${entry.level.name.toUpperCase()}] ${entry.message}');
    if (entry.context.isNotEmpty) {
      buffer.write(' ${_formatContext(entry.context)}');
    }
    logHandler(
      buffer.toString(),
      name: entry.loggerName.isNotEmpty ? entry.loggerName : name,
      level: _toDeveloperLevel(entry.level),
      time: entry.timestamp,
    );
  }

  String _formatContext(Map<String, Object?> context) =>
      context.entries.map((e) => '${e.key}=${e.value}').join(' ');

  static int _toDeveloperLevel(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
    LogLevel.fatal => 1200,
  };

  @override
  void dispose() {}
}
