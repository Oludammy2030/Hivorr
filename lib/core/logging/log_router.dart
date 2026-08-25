import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_sink.dart';

/// Dispatches [LogEntry] records to one or more [LogSink]s, discarding any
/// entry below the configured [minimumLevel] (EP-01-14 §5.9).
class LogRouter implements LogSink {
  LogRouter({required this.sinks, required this.minimumLevel});

  /// Active sinks for the current environment.
  final List<LogSink> sinks;

  /// Minimum level threshold; entries below this are discarded.
  final LogLevel minimumLevel;

  @override
  void write(LogEntry entry) {
    if (!entry.level.meetsThreshold(minimumLevel)) return;
    for (final sink in sinks) {
      sink.write(entry);
    }
  }

  @override
  void dispose() {
    for (final sink in sinks) {
      sink.dispose();
    }
  }
}
