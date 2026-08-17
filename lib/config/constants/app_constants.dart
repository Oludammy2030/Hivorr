/// Centralized, immutable, non-secret application constants.
///
/// This class contains only globally stable, non-secret values such as
/// configuration variable names, the supported configuration schema version,
/// and application identifiers. Security-sensitive values must never be
/// represented as source-level constants (EP-01-03 §5.7).
///
/// The static members define the compile-time variable contract consumed by
/// [EnvironmentLoader] and [FeatureFlags]. The const constructor allows the
/// immutable instance to be carried inside [EnvironmentConfig] as part of the
/// single configuration contract.
class AppConstants {
  const AppConstants();

  // ─── Configuration schema version ───────────────────────────────────

  /// The currently supported configuration schema version.
  ///
  /// The loader rejects any value that does not match this version,
  /// preventing configuration drift across incompatible releases.
  static const int supportedConfigSchemaVersion = 1;

  // ─── Compile-time variable names ────────────────────────────────────

  /// Environment identifier: `development`, `staging`, or `production`.
  static const String envEnvironment = 'HIVORR_ENV';

  /// Supabase project HTTPS URL.
  static const String envSupabaseUrl = 'HIVORR_SUPABASE_URL';

  /// Supabase public client (anon) key. Never a service-role key.
  static const String envSupabaseAnonKey = 'HIVORR_SUPABASE_ANON_KEY';

  /// Configuration schema version.
  static const String envConfigSchemaVersion = 'HIVORR_CONFIG_SCHEMA_VERSION';

  // ─── Feature flag variable names ────────────────────────────────────

  static const String featureEnableVerboseLogging =
      'HIVORR_FEATURE_ENABLE_VERBOSE_LOGGING';

  static const String featureEnableOfflineSync =
      'HIVORR_FEATURE_ENABLE_OFFLINE_SYNC';

  static const String featureEnableAnalyticsTracking =
      'HIVORR_FEATURE_ENABLE_ANALYTICS_TRACKING';

  static const String featureEnableDynamicWorkspaceLoading =
      'HIVORR_FEATURE_ENABLE_DYNAMIC_WORKSPACE_LOADING';

  // ─── Application identifiers ────────────────────────────────────────

  /// Human-readable application name.
  static const String applicationName = 'Hivorr';

  /// Application bundle identifier.
  static const String applicationId = 'ai.hivorr.app';
}
