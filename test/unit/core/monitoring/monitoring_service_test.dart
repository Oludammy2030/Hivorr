import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/monitoring_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../test_sentry_helper.dart';

MonitoringConfig _activeConfig() => MonitoringConfig.fromSource(
      MapEnvironmentValueSource(<String, String>{
        'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
        'HIVORR_MONITORING_SENTRY_DSN': 'https://x@y/1',
        'HIVORR_MONITORING_ENABLE_PII_REDACTION': 'true',
      }),
    );

Future<SentryEvent> _flush() async {
  await Sentry.captureMessage('__flush__');
  return recordedSentryEvents.firstWhere(
    (SentryEvent e) => e.message?.formatted == '__flush__',
  );
}

void main() {
  setUpAll(() async => setUpSentryRecording());
  setUp(() async => resetSentryScope());

  test('captureException delegates to Sentry when enabled', () async {
    final service = MonitoringService(_activeConfig());
    await service.captureException(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recordedSentryEvents, isNotEmpty);
  });

  test('captureException is a no-op when disabled', () async {
    final service = MonitoringService(
      MonitoringConfig.fromSource(const MapEnvironmentValueSource({})),
    );
    await service.captureException(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recordedSentryEvents, isEmpty);
  });

  test('addBreadcrumb redacts sensitive data before reaching Sentry', () async {
    final service = MonitoringService(_activeConfig());
    await service.addBreadcrumb(
      'auth',
      'login',
      data: <String, Object?>{'password': 'secret', 'action': 'ok'},
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final crumb = (await _flush()).breadcrumbs!.last;
    expect(crumb.category, 'auth');
    expect(crumb.data?['password'], '[REDACTED]');
    expect(crumb.data?['action'], 'ok');
  });

  test('setUserContext sets only the entity id', () async {
    final service = MonitoringService(_activeConfig());
    await service.setUserContext('entity-uuid');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((await _flush()).user?.id, 'entity-uuid');
  });

  test('clearUserContext removes the user', () async {
    final service = MonitoringService(_activeConfig());
    await service.setUserContext('entity-uuid');
    await service.clearUserContext();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((await _flush()).user, isNull);
  });

  test('setTag sets a Sentry tag', () async {
    final service = MonitoringService(_activeConfig());
    await service.setTag('env', 'test');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((await _flush()).tags?['env'], 'test');
  });
}
