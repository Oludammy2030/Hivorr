import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'test_logging_helpers.dart';

void main() {
  late RecordingSink sink;
  late LogRouter router;
  late HivorrLogger logger;

  setUp(() {
    sink = RecordingSink();
    router = LogRouter(sinks: [sink], minimumLevel: LogLevel.debug);
    logger = HivorrLogger('hivorr.test', router, PiiRedactor());
  });

  test('debug call produces a debug entry with the logger name', () {
    logger.debug('hello');
    expect(sink.entries, hasLength(1));
    expect(sink.entries.first.level, LogLevel.debug);
    expect(sink.entries.first.loggerName, 'hivorr.test');
    expect(sink.entries.first.message, 'hello');
  });

  test('error call carries error and stack trace', () {
    final err = Exception('boom');
    final st = StackTrace.current;
    logger.error('failed', error: err, stackTrace: st);
    expect(sink.entries.first.level, LogLevel.error);
    expect(sink.entries.first.error, err);
    expect(sink.entries.first.stackTrace, st);
  });

  test('message is PII-redacted before entry construction', () {
    logger.info('email user@example.com');
    expect(sink.entries.first.message, 'email ***@***.***');
  });

  test('context is PII-redacted before entry construction', () {
    logger.info('x', <String, Object?>{'password': 'secret', 'action': 'y'});
    expect(sink.entries.first.context['password'], '[REDACTED]');
    expect(sink.entries.first.context['action'], 'y');
  });
}
