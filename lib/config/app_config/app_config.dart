import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_loader.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/database/database_config.dart';

/// Application-facing configuration façade.
///
/// Provides one stable configuration contract for all future application
/// systems (EP-01-03 §6). Consumers call [AppConfig.load] during
/// application initialization and access deployment metadata through the
/// returned immutable instance.
///
/// This façade wraps [EnvironmentConfig] and delegates all access. It
/// ensures that future modules never need to read compile-time variables
/// directly.
class AppConfig {
  const AppConfig(this._config);

  final EnvironmentConfig _config;

  /// Loads and validates configuration from [source].
  ///
  /// Defaults to [CompileTimeEnvironmentValueSource] for production use.
  /// Unit tests inject [MapEnvironmentValueSource].
  factory AppConfig.load({
    EnvironmentValueSource source = const CompileTimeEnvironmentValueSource(),
  }) {
    return AppConfig(EnvironmentLoader.load(source: source));
  }

  // ─── Environment identity ───────────────────────────────────────────

  /// The validated environment identity.
  AppEnvironment get environment => _config.environment;

  /// Whether this configuration targets Production.
  bool get isProduction => _config.isProduction;

  /// Whether this configuration targets Staging.
  bool get isStaging => _config.isStaging;

  /// Whether this configuration targets Development.
  bool get isDevelopment => _config.isDevelopment;

  // ─── Supabase configuration ─────────────────────────────────────────

  /// The validated Supabase endpoint and public key.
  SupabaseConfig get supabaseConfig => _config.supabaseConfig;

  /// The validated HTTPS Supabase project URL.
  String get supabaseUrl => _config.supabaseConfig.url;

  /// The validated public Supabase client (anon) key.
  String get supabaseAnonKey => _config.supabaseConfig.anonKey;

  /// Validated security configuration (pinning, KDF parameters).
  SecurityConfig get securityConfig => _config.securityConfig;

  /// Validated local storage configuration (driver, at-rest encryption).
  DatabaseConfig get databaseConfig => _config.databaseConfig;

  /// Validated in-memory cache configuration (capacity, TTL).
  CacheConfig get cacheConfig => _config.cacheConfig;

  // ─── Feature flags ──────────────────────────────────────────────────

  /// Typed, environment-specific feature flags.
  FeatureFlags get featureFlags => _config.featureFlags;

  // ─── Constants ──────────────────────────────────────────────────────

  /// Centralized immutable application constants.
  AppConstants get constants => _config.constants;

  // ─── Raw configuration access ───────────────────────────────────────

  /// The underlying [EnvironmentConfig] wrapped by this façade.
  ///
  /// Exposed so downstream foundation tasks (e.g. EP-01-07/EP-01-15) can pass
  /// the validated configuration contract directly to modules that require
  /// the raw [EnvironmentConfig] (such as [ApiInitializer.initializeApi]).
  /// Consumers should prefer the typed façade getters above whenever possible.
  EnvironmentConfig get environmentConfig => _config;

  // ─── Schema version ─────────────────────────────────────────────────

  /// The validated configuration schema version.
  int get schemaVersion => _config.schemaVersion;

  @override
  String toString() => _config.toString();
}
