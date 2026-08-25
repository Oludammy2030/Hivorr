import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import '../test_sentry_helper.dart';

MonitoringConfig _activeConfig() => MonitoringConfig.fromSource(
      MapEnvironmentValueSource(<String, String>{
        'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
        'HIVORR_MONITORING_SENTRY_DSN': 'https://x@y/1',
        'HIVORR_MONITORING_TRACE_SAMPLE_RATE': '1.0',
      }),
    );

FeatureFlags _flags({required bool analytics}) => FeatureFlags(
      enableVerboseLogging: false,
      enableOfflineSync: false,
      enableAnalyticsTracking: analytics,
      enableDynamicWorkspaceLoading: false,
      enablePayloadOptimization: false,
    );

void main() {
  setUpAll(() async => setUpSentryRecording());

  test('isEnabled is false when analytics tracking is disabled', () {
    final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: false));
    expect(tracer.isEnabled, isFalse);
  });

  test('isEnabled is true when analytics + Sentry are active', () {
    final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: true));
    expect(tracer.isEnabled, isTrue);
  });

  test('startTransaction returns null when disabled', () {
    final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: false));
    expect(tracer.startTransaction('t', 'op'), isNull);
  });

  test('startTransaction returns a span when enabled', () {
    final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: true));
    final span = tracer.startTransaction('navigation', 'ui.load');
    expect(span, isNotNull);
  });

  test('startChildSpan creates a child under a parent', () {
    final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: true));
    final parent = tracer.startTransaction('parent', 'op')!;
    final child = tracer.startChildSpan(parent, 'child', 'ui.render');
    expect(child, isNotNull);
  });

  test('finishSpan handles a null span without error', () async {
    final tracer = PerformanceTracer(_activeConfig(), _flags(analytics: true));
    expect(() => tracer.finishSpan(null), returnsNormally);
  });
}
