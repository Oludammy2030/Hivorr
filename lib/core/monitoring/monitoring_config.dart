import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/logging/log_level.dart';

/// Immutable monitoring/telemetry configuration for the Hivorr client.
///
/// All values are sourced exclusively from [EnvironmentConfig] (via the
/// compile-time defines in EP-01-03); nothing here is a hardcoded secret or
/// literal. Sentry is disabled unless both [enableSentry] is `true` and
/// [sentryDsn] is non-empty (EP-01-14 §5.11).
class MonitoringConfig {
  const MonitoringConfig({
    required this.sentryDsn,
    required this.environment,
    required this.release,
    required this.traceSampleRate,
    required this.profileSampleRate,
    required this.enableSentry,
    required this.minimumLogLevel,
    required this.enablePiiRedaction,
    required this.maxBreadcrumbCount,
  });

  /// Sentry project DSN. Empty means Sentry is disabled.
  final String sentryDsn;

  /// Sentry environment tag (`development`, `staging`, `production`).
  final String environment;

  /// Sentry release tag (app version).
  final String release;

  /// Performance trace sample rate (0.0–1.0).
  final double traceSampleRate;

  /// Profiling sample rate (0.0–1.0).
  final double profileSampleRate;

  /// Master enable for the Sentry SDK.
  final bool enableSentry;

  /// Minimum log level name (parsed to [LogLevel]).
  final String minimumLogLevel;

  /// Master enable for PII redaction.
  final bool enablePiiRedaction;

  /// Maximum breadcrumbs retained by the Sentry SDK.
  final int maxBreadcrumbCount;

  /// Whether Sentry is active (enabled AND has a DSN).
  bool get isSentryActive => enableSentry && sentryDsn.isNotEmpty;

  /// Minimum [LogLevel] parsed from [minimumLogLevel].
  LogLevel get minimumLevel => LogLevel.parse(minimumLogLevel);

  /// Builds [MonitoringConfig] from an [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults so the loader stays fail-closed
  /// on the core Supabase/schema contract while monitoring remains opt-in per
  /// environment (EP-01-14 §5.17).
  static MonitoringConfig fromSource(EnvironmentValueSource source) {
    final sentryDsn =
        source.read(AppConstants.envMonitoringSentryDsn) ??
        AppConstants.defaultMonitoringSentryDsn;
    final environment =
        source.read(AppConstants.envMonitoringEnvironment) ??
        AppConstants.defaultMonitoringEnvironment;
    final release = source.read(AppConstants.envMonitoringRelease) ??
        AppConstants.defaultMonitoringRelease;
    final traceSampleRate = _parseDouble(
      source,
      AppConstants.envMonitoringTraceSampleRate,
      AppConstants.defaultMonitoringTraceSampleRate,
    );
    final profileSampleRate = _parseDouble(
      source,
      AppConstants.envMonitoringProfileSampleRate,
      AppConstants.defaultMonitoringProfileSampleRate,
    );
    final enableSentry = _parseBool(
      source,
      AppConstants.envMonitoringEnableSentry,
      AppConstants.defaultMonitoringEnableSentry,
    );
    final minimumLogLevel =
        source.read(AppConstants.envMonitoringMinLogLevel) ??
        AppConstants.defaultMonitoringMinLogLevel;
    final enablePiiRedaction = _parseBool(
      source,
      AppConstants.envMonitoringEnablePiiRedaction,
      AppConstants.defaultMonitoringEnablePiiRedaction,
    );
    final maxBreadcrumbCount = _parseInt(
      source,
      AppConstants.envMonitoringMaxBreadcrumbs,
      AppConstants.defaultMonitoringMaxBreadcrumbs,
    );

    return MonitoringConfig(
      sentryDsn: sentryDsn,
      environment: environment,
      release: release,
      traceSampleRate: traceSampleRate,
      profileSampleRate: profileSampleRate,
      enableSentry: enableSentry,
      minimumLogLevel: minimumLogLevel,
      enablePiiRedaction: enablePiiRedaction,
      maxBreadcrumbCount: maxBreadcrumbCount,
    );
  }

  static double _parseDouble(
    EnvironmentValueSource source,
    String key,
    double fallback,
  ) {
    final raw = source.read(key);
    if (raw == null) return fallback;
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Monitoring value must be a number.',
      );
    }
    return parsed.clamp(0.0, 1.0);
  }

  static int _parseInt(
    EnvironmentValueSource source,
    String key,
    int fallback,
  ) {
    final raw = source.read(key);
    if (raw == null) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Monitoring value must be an integer.',
      );
    }
    return parsed < 0 ? 0 : parsed;
  }

  static bool _parseBool(
    EnvironmentValueSource source,
    String key,
    bool fallback,
  ) {
    final raw = source.read(key);
    if (raw == null) return fallback;
    return switch (raw) {
      'true' => true,
      'false' => false,
      _ => throw EnvironmentConfigException(
          variableName: key,
          reason: 'Malformed monitoring flag. Accepted values: true, false.',
        ),
    };
  }

  @override
  String toString() {
    return 'MonitoringConfig('
        'environment: $environment, '
        'enableSentry: $enableSentry, '
        'minimumLogLevel: $minimumLogLevel, '
        'enablePiiRedaction: $enablePiiRedaction)';
  }
}
