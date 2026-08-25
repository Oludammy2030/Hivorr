import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'test_logging_helpers.dart';

void main() {
  late RecordingSink sink;
  late LogRouter router;
  late LoggerFactory factory;

  setUp(() {
    sink = RecordingSink();
    router = LogRouter(sinks: [sink], minimumLevel: LogLevel.debug);
    factory = LoggerFactory(router, PiiRedactor());
  });

  test('named returns a logger bound to the given name', () {
    final logger = factory.named('hivorr.sync');
    expect(logger, isA<HivorrLogger>());
    logger.debug('x');
    expect(sink.entries.first.loggerName, 'hivorr.sync');
  });

  test('repeated names return independent logger instances', () {
    final a = factory.named('a');
    final b = factory.named('b');
    expect(a, isNot(same(b)));
  });
}
