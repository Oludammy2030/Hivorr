import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/logging/api_log_sink.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/logging/sentry_api_log_sink.dart';
import 'test_logging_helpers.dart';

void main() {
  late RecordingSink sink;
  late HivorrLogger logger;
  late SentryApiLogSink apiSink;

  setUp(() {
    sink = RecordingSink();
    final router = LogRouter(sinks: [sink], minimumLevel: LogLevel.debug);
    logger = HivorrLogger('hivorr.api', router, PiiRedactor());
    apiSink = SentryApiLogSink(logger);
  });

  test('routes known levels to the matching logger method', () {
    apiSink.log('debug', 'd');
    apiSink.log('info', 'i');
    apiSink.log('warning', 'w');
    apiSink.log('error', 'e');
    apiSink.log('fatal', 'f');
    expect(sink.entries.map((e) => e.level).toList(), <LogLevel>[
      LogLevel.debug,
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
      LogLevel.fatal,
    ]);
  });

  test('unknown level defaults to info', () {
    apiSink.log('trace', 'u');
    expect(sink.entries.last.level, LogLevel.info);
  });

  test('implements the EP-01-07 ApiLogSink interface', () {
    expect(apiSink, isA<ApiLogSink>());
  });
}
