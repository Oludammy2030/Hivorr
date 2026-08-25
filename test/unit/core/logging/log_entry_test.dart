import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';

void main() {
  test('construction with all fields', () {
    final stack = StackTrace.current;
    final entry = LogEntry(
      level: LogLevel.error,
      message: 'boom',
      loggerName: 'hivorr.test',
      timestamp: DateTime(2024),
      context: <String, Object?>{'action': 'login'},
      error: Exception('x'),
      stackTrace: stack,
    );
    expect(entry.level, LogLevel.error);
    expect(entry.message, 'boom');
    expect(entry.loggerName, 'hivorr.test');
    expect(entry.context['action'], 'login');
    expect(entry.error, isA<Exception>());
    expect(entry.stackTrace, stack);
    expect(entry.hasError, isTrue);
  });

  test('null error and stack trace are allowed', () {
    final entry = LogEntry(
      level: LogLevel.info,
      message: 'm',
      loggerName: 'n',
      timestamp: DateTime(2024),
    );
    expect(entry.error, isNull);
    expect(entry.stackTrace, isNull);
    expect(entry.hasError, isFalse);
  });

  test('context is an unmodifiable defensive copy', () {
    final source = <String, Object?>{'k': 'v'};
    final entry = LogEntry(
      level: LogLevel.info,
      message: 'm',
      loggerName: 'n',
      timestamp: DateTime(2024),
      context: source,
    );
    source['k'] = 'changed';
    expect(entry.context['k'], 'v');
    expect(() => entry.context['z'] = 'mutate', throwsUnsupportedError);
  });
}
