import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_sink.dart';

/// Test-only [LogSink] that records every entry it receives.
class RecordingSink implements LogSink {
  final List<LogEntry> entries = <LogEntry>[];

  @override
  void write(LogEntry entry) => entries.add(entry);

  @override
  void dispose() {}
}
