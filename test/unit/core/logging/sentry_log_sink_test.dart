import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/sentry_log_sink.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../test_sentry_helper.dart';

LogEntry _entry(LogLevel level, {Object? error}) => LogEntry(
      level: level,
      message: 'msg-${level.name}',
      loggerName: 'hivorr.test',
      timestamp: DateTime(2024),
      error: error,
    );

Future<List<Breadcrumb>> _flushBreadcrumbs() async {
  await Sentry.captureMessage('__flush__');
  final flush = recordedSentryEvents.firstWhere(
    (SentryEvent e) => e.message?.formatted == '__flush__',
  );
  return flush.breadcrumbs ?? const <Breadcrumb>[];
}

void main() {
  setUpAll(() async => setUpSentryRecording());
  setUp(() async => resetSentryScope());

  test('debug/info/warning produce breadcrumbs', () async {
    const SentryLogSink().write(_entry(LogLevel.debug));
    const SentryLogSink().write(_entry(LogLevel.info));
    const SentryLogSink().write(_entry(LogLevel.warning));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final crumbs = await _flushBreadcrumbs();
    expect(crumbs.any((Breadcrumb c) => c.message == 'msg-debug'), isTrue);
    expect(crumbs.any((Breadcrumb c) => c.message == 'msg-info'), isTrue);
    expect(crumbs.any((Breadcrumb c) => c.message == 'msg-warning'), isTrue);
  });

  test('error with an error object is captured as an exception', () async {
    const SentryLogSink().write(_entry(LogLevel.error, error: Exception('boom')));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recordedSentryEvents, isNotEmpty);
  });

  test('error without an error object is captured as a message', () async {
    const SentryLogSink().write(_entry(LogLevel.error));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      recordedSentryEvents
          .any((SentryEvent e) => e.message?.formatted == 'msg-error'),
      isTrue,
    );
  });

  test('fatal without an error object is captured as a message', () async {
    const SentryLogSink().write(_entry(LogLevel.fatal));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      recordedSentryEvents
          .any((SentryEvent e) => e.message?.formatted == 'msg-fatal'),
      isTrue,
    );
  });
}
