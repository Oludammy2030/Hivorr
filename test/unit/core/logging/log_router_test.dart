import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'test_logging_helpers.dart';

class _RecordingSink implements LogSink {
  final List<LogEntry> entries = <LogEntry>[];
  @override
  void write(LogEntry entry) => entries.add(entry);
  @override
  void dispose() {}
}

LogEntry _entry(LogLevel level) => LogEntry(
      level: level,
      message: 'm',
      loggerName: 'n',
      timestamp: DateTime(2024),
    );

void main() {
  test('entries below minimum level are discarded', () {
    final sink = _RecordingSink();
    final router = LogRouter(sinks: [sink], minimumLevel: LogLevel.warning);
    router.write(_entry(LogLevel.debug));
    router.write(_entry(LogLevel.info));
    expect(sink.entries, isEmpty);
  });

  test('entries at and above minimum level are delivered', () {
    final sink = _RecordingSink();
    final router = LogRouter(sinks: [sink], minimumLevel: LogLevel.warning);
    router.write(_entry(LogLevel.warning));
    router.write(_entry(LogLevel.error));
    router.write(_entry(LogLevel.fatal));
    expect(sink.entries.length, 3);
  });

  test('multiple sinks all receive the entry', () {
    final a = _RecordingSink();
    final b = _RecordingSink();
    final router = LogRouter(sinks: [a, b], minimumLevel: LogLevel.debug);
    router.write(_entry(LogLevel.debug));
    expect(a.entries.length, 1);
    expect(b.entries.length, 1);
  });

  test('empty sink list does not crash', () {
    final router = LogRouter(sinks: [], minimumLevel: LogLevel.debug);
    expect(() => router.write(_entry(LogLevel.debug)), returnsNormally);
  });

  test('dispose forwards to all sinks', () {
    final sink = RecordingSink();
    final router = LogRouter(sinks: [sink], minimumLevel: LogLevel.debug);
    router.dispose();
    expect(sink.entries, isEmpty);
  });
}
