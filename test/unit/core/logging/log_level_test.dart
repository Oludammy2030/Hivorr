import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/log_level.dart';

void main() {
  test('severity values are in order', () {
    expect(LogLevel.debug.severity, 0);
    expect(LogLevel.info.severity, 1);
    expect(LogLevel.warning.severity, 2);
    expect(LogLevel.error.severity, 3);
    expect(LogLevel.fatal.severity, 4);
  });

  test('meetsThreshold compares against severity', () {
    expect(LogLevel.debug.meetsThreshold(LogLevel.debug), isTrue);
    expect(LogLevel.debug.meetsThreshold(LogLevel.warning), isFalse);
    expect(LogLevel.fatal.meetsThreshold(LogLevel.debug), isTrue);
    expect(LogLevel.error.meetsThreshold(LogLevel.error), isTrue);
    expect(LogLevel.warning.meetsThreshold(LogLevel.fatal), isFalse);
  });

  test('exactly five levels are defined', () {
    expect(LogLevel.values.length, 5);
  });

  test('parse is case-insensitive with safe default', () {
    expect(LogLevel.parse('DEBUG'), LogLevel.debug);
    expect(LogLevel.parse('warning'), LogLevel.warning);
    expect(LogLevel.parse('FATAL'), LogLevel.fatal);
    expect(LogLevel.parse('not-a-level'), LogLevel.debug);
  });
}
