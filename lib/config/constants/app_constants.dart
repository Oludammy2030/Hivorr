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

  // ─── Security configuration variable names (EP-01-10) ───────────────

  /// Whether SSL certificate pinning is enabled for the environment.
  static const String securityPinningEnabled =
      'HIVORR_SECURITY_PINNING_ENABLED';

  /// Comma-separated list of SPKI SHA-256 (base64) certificate pins.
  static const String securityPinnedSpkiHashes =
      'HIVORR_SECURITY_PINNED_SPKI_HASHES';

  /// PBKDF2 salt (non-secret) for deriving encryption keys at rest.
  static const String securityKdfSalt = 'HIVORR_SECURITY_KDF_SALT';

  /// PBKDF2 iteration count for deriving encryption keys at rest.
  static const String securityKdfIterations =
      'HIVORR_SECURITY_KDF_ITERATIONS';

  /// Derived encryption key length in bytes (16/24/32 for AES).
  static const String securityKdfKeyLength = 'HIVORR_SECURITY_KDF_KEY_LENGTH';

  // ─── Security configuration safe defaults (EP-01-10) ────────────────

  /// Default PBKDF2 salt when not supplied (non-secret, environment-stable).
  static const String defaultKdfSalt = 'hivorr-security-kdf-salt-v1';

  /// Default PBKDF2 iteration count (resistant to offline attacks).
  static const int defaultKdfIterations = 100000;

  /// Default derived key length in bytes (AES-256).
  static const int defaultKdfKeyLength = 32;

  // ─── Application identifiers ────────────────────────────────────────

  /// Human-readable application name.
  static const String applicationName = 'Hivorr';

  /// Application bundle identifier.
  static const String applicationId = 'ai.hivorr.app';
}
