// The `beforeSend` hook legitimately reads/writes the deprecated `extra` map and
// `SentryRequest.headers`; this is the only supported SDK surface for the PII
// stripping hook.
// ignore_for_file: deprecated_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/sentry_initializer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('disabled config does not invoke the init callback', () async {
    var called = false;
    final cfg = MonitoringConfig.fromSource(MapEnvironmentValueSource(
      <String, String>{'HIVORR_MONITORING_ENABLE_SENTRY': 'false'},
    ));
    await SentryInitializer.initialize(cfg, init: (optionsConfig) async {
      called = true;
    });
    expect(called, isFalse);
  });

  test('enabled config invokes init and applies options', () async {
    SentryFlutterOptions? captured;
    final cfg = MonitoringConfig.fromSource(MapEnvironmentValueSource(<String, String>{
      'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
      'HIVORR_MONITORING_SENTRY_DSN': 'https://x@y/1',
      'HIVORR_MONITORING_ENVIRONMENT': 'staging',
      'HIVORR_MONITORING_RELEASE': 'v1',
      'HIVORR_MONITORING_TRACE_SAMPLE_RATE': '0.3',
      'HIVORR_MONITORING_MAX_BREADCRUMBS': '42',
      'HIVORR_MONITORING_MIN_LOG_LEVEL': 'info',
    }));
    await SentryInitializer.initialize(cfg, init: (optionsConfig) async {
      final options = SentryFlutterOptions();
      await optionsConfig(options);
      captured = options;
    });
    expect(captured, isNotNull);
    expect(captured!.dsn, 'https://x@y/1');
    expect(captured!.environment, 'staging');
    expect(captured!.release, 'v1');
    expect(captured!.tracesSampleRate, 0.3);
    expect(captured!.maxBreadcrumbs, 42);
    expect(captured!.debug, isFalse);
    expect(captured!.beforeSend, isNotNull);
  });

  group('sentryBeforeSend PII stripping', () {
    test('removes the Authorization header', () {
      final event = SentryEvent(
        request: SentryRequest(headers: <String, String>{
          'Authorization': 'Bearer secret',
          'X-Other': 'keep',
        }),
      );
      final result = sentryBeforeSend(event, Hint())!;
      final headers = result.request?.headers;
      expect(headers?.containsKey('Authorization'), isFalse);
      expect(headers?.containsKey('X-Other'), isTrue);
    });

    test('removes the Cookie header', () {
      final event = SentryEvent(
        request: SentryRequest(headers: <String, String>{
          'Cookie': 'session=abc',
        }),
      );
      final result = sentryBeforeSend(event, Hint())!;
      final headers = result.request?.headers;
      expect(headers?.containsKey('Cookie'), isFalse);
    });

    test('removes sensitive extra keys', () {
      final event = SentryEvent(extra: <String, dynamic>{
        'password': 'p',
        'action': 'ok',
      });
      final result = sentryBeforeSend(event, Hint())!;
      final extra = result.extra;
      expect(extra?.containsKey('password'), isFalse);
      expect(extra?.containsKey('action'), isTrue);
    });

    test('returns the event unchanged when nothing is sensitive', () {
      final event = SentryEvent(extra: <String, dynamic>{'action': 'ok'});
      final result = sentryBeforeSend(event, Hint())!;
      expect(result.extra?.containsKey('action'), isTrue);
    });
  });
}
