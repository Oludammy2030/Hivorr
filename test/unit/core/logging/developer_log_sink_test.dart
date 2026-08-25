import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/developer_log_sink.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';

void main() {
  test('write routes a formatted message to the handler', () {
    String? capturedMessage;
    int? capturedLevel;
    String? capturedName;

    final sink = DeveloperLogSink(
      logHandler: (message, {level = 0, name = '', DateTime? time}) {
        capturedMessage = message;
        capturedLevel = level;
        capturedName = name;
      },
    );

    sink.write(
      LogEntry(
        level: LogLevel.error,
        message: 'boom',
        loggerName: 'hivorr.x',
        timestamp: DateTime(2024),
        context: <String, Object?>{'action': 'fail'},
      ),
    );

    expect(capturedMessage, contains('[ERROR] boom'));
    expect(capturedMessage, contains('action=fail'));
    expect(capturedName, 'hivorr.x');
    expect(capturedLevel, 1000);
    sink.dispose();
  });

  test('does not use print (uses injected handler)', () {
    var calls = 0;
    final sink = DeveloperLogSink(
      logHandler: (message, {level = 0, name = '', DateTime? time}) => calls++,
    );
    sink.write(
      LogEntry(
        level: LogLevel.debug,
        message: 'd',
        loggerName: 'n',
        timestamp: DateTime(2024),
      ),
    );
    expect(calls, 1);
  });
}
