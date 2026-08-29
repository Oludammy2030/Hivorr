import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/database/database_config.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/network/network_config.dart';
import 'package:hivorr/core/notifications/notification_config.dart';
import 'package:hivorr/core/sync/sync_config.dart';

/// Immutable Supabase endpoint configuration.
///
/// Contains only the public client (anon) key. Service-role keys are
/// rejected during loading and never appear in this model (EP-01-03 §5.4,
/// §12).
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  /// The validated HTTPS Supabase project URL.
  final String url;

  /// The validated public Supabase client (anon) key.
  final String anonKey;

  @override
  String toString() => 'SupabaseConfig(url: [redacted], anonKey: [redacted])';
}

/// Immutable aggregate environment configuration.
///
/// One configuration object carries every piece of deployment metadata
/// that future application systems need (EP-01-03 §5.3). Consumers never
/// read compile-time variables directly — they access everything through
/// this contract or the [AppConfig] façade.
class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.supabaseConfig,
    required this.featureFlags,
    required this.securityConfig,
    required this.databaseConfig,
    required this.cacheConfig,
    required this.syncConfig,
    required this.networkConfig,
    required this.monitoringConfig,
    required this.notificationConfig,
    required this.constants,
    required this.schemaVersion,
  });

  /// The validated environment identity.
  final AppEnvironment environment;

  /// The validated Supabase endpoint and public key.
  final SupabaseConfig supabaseConfig;

  /// Typed, environment-specific feature flags.
  final FeatureFlags featureFlags;

  /// Validated security configuration (pinning, KDF parameters).
  final SecurityConfig securityConfig;

  /// Validated local storage configuration (driver, at-rest encryption).
  final DatabaseConfig databaseConfig;

  /// Validated in-memory cache configuration (capacity, TTL).
  final CacheConfig cacheConfig;

  /// Validated offline sync configuration (retry policy, backoff, queue depth).
  final SyncConfig syncConfig;

  /// Validated network management configuration (debounce, payload optimization).
  final NetworkConfig networkConfig;

  /// Validated monitoring/telemetry configuration (Sentry, log levels, redaction).
  final MonitoringConfig monitoringConfig;

  /// Validated notification engine configuration (channels, push, icon).
  final NotificationConfig notificationConfig;

  /// Centralized immutable application constants.
  final AppConstants constants;

  /// The validated configuration schema version.
  final int schemaVersion;

  /// Whether this configuration targets Production.
  ///
  /// Derived from the validated [environment] enum, not `kDebugMode`.
  bool get isProduction => environment.isProduction;

  /// Whether this configuration targets Staging.
  bool get isStaging => environment.isStaging;

  /// Whether this configuration targets Development.
  bool get isDevelopment => environment.isDevelopment;

  @override
  String toString() {
    return 'EnvironmentConfig('
        'environment: $environment, '
        'schemaVersion: $schemaVersion, '
        'notificationConfig: $notificationConfig)';
  }

  /// Whether local data is encrypted at rest for this environment.
  bool get isStorageEncryptedAtRest => databaseConfig.encryptAtRest;
}
