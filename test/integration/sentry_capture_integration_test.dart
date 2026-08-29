// Integration validation for EP-01-14 (Monitoring & Logging): Sentry capture,
// breadcrumbs, PII redaction, performance tracing, and environment-aware config.
//
// This test composes REAL production objects (MonitoringService, PerformanceTracer,
// HivorrLogger, PiiRedactor, LogRouter, SentryLogSink) and only fakes the Sentry
// transport via SentryRecordingHarness + RecordingSink. No real secrets are used;
// all DSN values are placeholders.
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/logging/sentry_log_sink.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/monitoring_service.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../support/fakes/fake_logging.dart';
import '../support/harnesses/sentry_harness.dart';

/// Distinct exception used so captured events can be identified by marker.
class _IntegrationError implements Exception {
  const _IntegrationError(this.marker);
  final String marker;
  @override
  String toString() => 'IntegrationError($marker)';
}

/// Active (Sentry-on) monitoring config built from test sources.
MonitoringConfig _activeConfig() => MonitoringConfig.fromSource(
      MapEnvironmentValueSource(<String, String>{
        'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
        'HIVORR_MONITORING_SENTRY_DSN':
            'https://active@o000000.ingest.sentry.io/1000',
        'HIVORR_MONITORING_ENABLE_PII_REDACTION': 'true',
        'HIVORR_MONITORING_ENVIRONMENT': 'test',
        'HIVORR_MONITORING_TRACE_SAMPLE_RATE': '1.0',
      }),
    );

FeatureFlags _flags({required bool analytics}) => FeatureFlags(
      enableVerboseLogging: false,
      enableOfflineSync: false,
      enableAnalyticsTracking: analytics,
      enableDynamicWorkspaceLoading: false,
      enablePayloadOptimization: false,
      enablePushNotifications: false,
    );

bool _eventMatches(SentryEvent event, String marker) {
  final throwableText = event.throwable?.toString() ?? '';
  final messageText = event.message?.formatted ?? '';
  return throwableText.contains(marker) || messageText.contains(marker);
}

void main() {
  final harness = SentryRecordingHarness();

  setUpAll(() async => harness.setUp());
  setUp(() async => harness.reset());

  group('Validation Point 6.1 — error capture', () {
    test('exception thrown inside a monitored operation is captured by Sentry',
        () async {
      final service = MonitoringService(_activeConfig());
      final err = const _IntegrationError('capture-explicit');

      Object? captured;
      try {
        throw err;
      } on Object catch (e, st) {
        captured = e;
        await service.captureException(e, stackTrace: st);
      }

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(captured, same(err));
      expect(harness.capturedEvents, isNotEmpty);
      expect(
        harness.capturedEvents.any((e) => _eventMatches(e, 'capture-explicit')),
        isTrue,
      );
    });

    test('logger error path routes through SentryLogSink to Sentry', () async {
      final redactor = PiiRedactor(enabled: true);
      final router = LogRouter(
        sinks: const <LogSink>[SentryLogSink()],
        minimumLevel: LogLevel.debug,
      );
      final logger = HivorrLogger('hivorr.api', router, redactor);
      final err = const _IntegrationError('capture-logger');

      logger.error('api call failed', error: err);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        harness.capturedEvents.any((e) => _eventMatches(e, 'capture-logger')),
        isTrue,
      );
    });
  });

  group('Validation Point 6.2 — breadcrumb recording', () {
    test('sequential operations record ordered breadcrumbs', () async {
      final service = MonitoringService(_activeConfig());

      await service.addBreadcrumb('auth', 'session established');
      await service.addBreadcrumb('api', 'request issued');
      await service.addBreadcrumb('data', 'profile cached');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final ordered = harness.capturedBreadcrumbs
          .where((b) => <String>['auth', 'api', 'data'].contains(b.category))
          .map((b) => b.category)
          .toList();

      expect(ordered, <String>['auth', 'api', 'data']);
    });
  });

  group('Validation Point 6.3 — PII redaction', () {
    test('email is redacted before reaching the RecordingSink', () async {
      final sink = RecordingSink();
      final router = LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug);
      final logger = HivorrLogger('hivorr.auth', router, PiiRedactor(enabled: true));

      logger.info('user signed up with user@example.com');

      expect(sink.entries, hasLength(1));
      expect(sink.entries.first.message, contains('***@***.***'));
      expect(sink.entries.first.message, isNot(contains('user@example.com')));
    });

    test('email is redacted before reaching the Sentry breadcrumb', () async {
      final service = MonitoringService(_activeConfig());

      await service.addBreadcrumb('auth', 'login for user@example.com');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final crumbs = harness.capturedBreadcrumbs
          .where((b) => b.category == 'auth')
          .toList();
      expect(crumbs, isNotEmpty);
      for (final crumb in crumbs) {
        expect(crumb.message, isNot(contains('user@example.com')));
        expect(crumb.message, contains('***@***.***'));
      }
    });
  });

  group('Validation Point 6.4 — performance trace', () {
    test('a started transaction records a child span and finishes', () async {
      final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: true));
      expect(tracer.isEnabled, isTrue);

      final span = tracer.startTransaction('bootstrap', 'app.start');
      expect(span, isNotNull);

      final child = tracer.startChildSpan(span!, 'load config', 'config.load');
      expect(child, isNotNull);

      // Simulate real work inside the span.
      final work = List<int>.generate(100, (i) => i * i);
      expect(work, hasLength(100));

      // Finishing the span must not throw and must complete.
      await tracer.finishSpan(span);
    });

    test('tracer is disabled without analytics tracking and returns no span',
        () async {
      final tracer =
          PerformanceTracer(_activeConfig(), _flags(analytics: false));
      expect(tracer.isEnabled, isFalse);
      expect(tracer.startTransaction('t', 'op'), isNull);
    });
  });

  group('Validation Point 6.5 — environment-aware Sentry config', () {
    // Dev: Sentry inactive, verbose (debug) logging, placeholder DSN.
    MonitoringConfig devConfig() => MonitoringConfig.fromSource(
          MapEnvironmentValueSource(<String, String>{
            'HIVORR_MONITORING_ENABLE_SENTRY': 'false',
            'HIVORR_MONITORING_SENTRY_DSN':
                'https://dev-placeholder@o000001.ingest.sentry.io/1',
            'HIVORR_MONITORING_ENVIRONMENT': 'development',
            'HIVORR_MONITORING_MIN_LOG_LEVEL': 'debug',
          }),
        );

    // Prod: Sentry active, reduced verbosity (warning), different placeholder DSN.
    MonitoringConfig prodConfig() => MonitoringConfig.fromSource(
          MapEnvironmentValueSource(<String, String>{
            'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
            'HIVORR_MONITORING_SENTRY_DSN':
                'https://prod-placeholder@o999999.ingest.sentry.io/9',
            'HIVORR_MONITORING_ENVIRONMENT': 'production',
            'HIVORR_MONITORING_MIN_LOG_LEVEL': 'warning',
          }),
        );

    test('dev and prod configs differ in DSN, environment, verbosity, and '
        'Sentry activation', () async {
      final dev = devConfig();
      final prod = prodConfig();

      expect(dev.sentryDsn, isNot(prod.sentryDsn));
      expect(dev.environment, isNot(prod.environment));
      expect(dev.minimumLogLevel, isNot(prod.minimumLogLevel));
      expect(dev.minimumLevel, LogLevel.debug);
      expect(prod.minimumLevel, LogLevel.warning);
      expect(dev.isSentryActive, isFalse);
      expect(prod.isSentryActive, isTrue);
    });
  });
}
