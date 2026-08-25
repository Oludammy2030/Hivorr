import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';

void main() {
  test('applies safe defaults when nothing is supplied', () {
    final cfg = MonitoringConfig.fromSource(const MapEnvironmentValueSource({}));
    expect(cfg.sentryDsn, '');
    expect(cfg.environment, 'development');
    expect(cfg.release, 'unknown');
    expect(cfg.traceSampleRate, 0.0);
    expect(cfg.profileSampleRate, 0.0);
    expect(cfg.enableSentry, isFalse);
    expect(cfg.minimumLogLevel, 'debug');
    expect(cfg.enablePiiRedaction, isTrue);
    expect(cfg.maxBreadcrumbCount, 100);
    expect(cfg.isSentryActive, isFalse);
    expect(cfg.minimumLevel, LogLevel.debug);
  });

  test('parses supplied values', () {
    final cfg = MonitoringConfig.fromSource(MapEnvironmentValueSource(<String, String>{
      'HIVORR_MONITORING_SENTRY_DSN': 'https://x@y/1',
      'HIVORR_MONITORING_ENVIRONMENT': 'staging',
      'HIVORR_MONITORING_RELEASE': 'v1.2.3',
      'HIVORR_MONITORING_TRACE_SAMPLE_RATE': '0.5',
      'HIVORR_MONITORING_PROFILE_SAMPLE_RATE': '0.25',
      'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
      'HIVORR_MONITORING_MIN_LOG_LEVEL': 'warning',
      'HIVORR_MONITORING_ENABLE_PII_REDACTION': 'false',
      'HIVORR_MONITORING_MAX_BREADCRUMBS': '50',
    }));
    expect(cfg.sentryDsn, 'https://x@y/1');
    expect(cfg.environment, 'staging');
    expect(cfg.release, 'v1.2.3');
    expect(cfg.traceSampleRate, 0.5);
    expect(cfg.profileSampleRate, 0.25);
    expect(cfg.enableSentry, isTrue);
    expect(cfg.minimumLogLevel, 'warning');
    expect(cfg.enablePiiRedaction, isFalse);
    expect(cfg.maxBreadcrumbCount, 50);
    expect(cfg.isSentryActive, isTrue);
    expect(cfg.minimumLevel, LogLevel.warning);
  });

  test('empty DSN keeps Sentry disabled even when enabled flag is true', () {
    final cfg = MonitoringConfig.fromSource(MapEnvironmentValueSource(
      <String, String>{'HIVORR_MONITORING_ENABLE_SENTRY': 'true'},
    ));
    expect(cfg.isSentryActive, isFalse);
  });

  test('sample rates are clamped to 0.0-1.0', () {
    final cfg = MonitoringConfig.fromSource(MapEnvironmentValueSource(
      <String, String>{'HIVORR_MONITORING_TRACE_SAMPLE_RATE': '5'},
    ));
    expect(cfg.traceSampleRate, 1.0);
  });

  test('malformed boolean throws EnvironmentConfigException', () {
    expect(
      () => MonitoringConfig.fromSource(MapEnvironmentValueSource(
        <String, String>{'HIVORR_MONITORING_ENABLE_SENTRY': 'yes'},
      )),
      throwsA(isA<EnvironmentConfigException>()),
    );
  });
}
