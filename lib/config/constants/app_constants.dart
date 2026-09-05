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
  static const String securityKdfIterations = 'HIVORR_SECURITY_KDF_ITERATIONS';

  /// Derived encryption key length in bytes (16/24/32 for AES).
  static const String securityKdfKeyLength = 'HIVORR_SECURITY_KDF_KEY_LENGTH';

  // ─── Local storage & cache configuration (EP-01-11) ────────────────

  /// Selected local storage driver: `hive` (default), `sqlite`, or `isar`.
  static const String envStorageDriver = 'HIVORR_STORAGE_DRIVER';

  /// Whether persisted local data is encrypted at rest.
  static const String envStorageEncryptAtRest =
      'HIVORR_STORAGE_ENCRYPT_AT_REST';

  /// Base directory name (under the app documents dir) for local storage.
  static const String envStorageBaseDir = 'HIVORR_STORAGE_BASE_DIR';

  /// Maximum number of in-memory cache entries before LRU eviction.
  static const String envCacheMaxEntries = 'HIVORR_CACHE_MAX_ENTRIES';

  /// Default cache entry TTL in seconds.
  static const String envCacheDefaultTtlSeconds =
      'HIVORR_CACHE_DEFAULT_TTL_SECONDS';

  /// Default local storage base directory name.
  static const String defaultStorageBaseDir = 'hivorr_local';

  /// Default maximum in-memory cache entries.
  static const int defaultCacheMaxEntries = 100;

  /// Default cache entry TTL in seconds (5 minutes).
  static const int defaultCacheDefaultTtlSeconds = 300;

  // ─── Offline sync configuration (EP-01-12) ─────────────────────────

  /// Maximum number of pending sync actions before the queue rejects new ones.
  static const String envSyncMaxQueueDepth = 'HIVORR_SYNC_MAX_QUEUE_DEPTH';

  /// Default per-action retry ceiling before dead-lettering.
  static const String envSyncMaxRetries = 'HIVORR_SYNC_MAX_RETRIES';

  /// Base delay (in milliseconds) for exponential backoff.
  static const String envSyncBaseDelayMs = 'HIVORR_SYNC_BASE_DELAY_MS';

  /// Maximum delay (in milliseconds) for exponential backoff.
  static const String envSyncMaxDelayMs = 'HIVORR_SYNC_MAX_DELAY_MS';

  /// Maximum random jitter (in milliseconds) added to each backoff delay.
  static const String envSyncJitterMaxMs = 'HIVORR_SYNC_JITTER_MAX_MS';

  /// Default priority assigned to sync actions (lower = higher priority).
  static const String envSyncDefaultPriority = 'HIVORR_SYNC_DEFAULT_PRIORITY';

  /// Maximum number of actions processed per drain cycle.
  static const String envSyncDrainBatchSize = 'HIVORR_SYNC_DRAIN_BATCH_SIZE';

  /// Default maximum queue depth.
  static const int defaultSyncMaxQueueDepth = 500;

  /// Default per-action retry ceiling.
  static const int defaultSyncMaxRetries = 5;

  /// Default base delay for exponential backoff (1 second).
  static const int defaultSyncBaseDelayMs = 1000;

  /// Default maximum delay for exponential backoff (60 seconds).
  static const int defaultSyncMaxDelayMs = 60000;

  /// Default maximum random jitter (1 second).
  static const int defaultSyncJitterMaxMs = 1000;

  /// Default action priority (lower = higher priority).
  static const int defaultSyncDefaultPriority = 10;

  /// Default drain batch size.
  static const int defaultSyncDrainBatchSize = 50;

  // ─── Security configuration safe defaults (EP-01-10) ────────────────

  /// Default PBKDF2 salt when not supplied (non-secret, environment-stable).
  static const String defaultKdfSalt = 'hivorr-security-kdf-salt-v1';

  /// Default PBKDF2 iteration count (resistant to offline attacks).
  static const int defaultKdfIterations = 100000;

  /// Default derived key length in bytes (AES-256).
  static const int defaultKdfKeyLength = 32;

  // ─── Network management configuration (EP-01-13) ──────────────────

  /// Connectivity change debounce interval in milliseconds (0 = no debounce).
  static const String envNetworkDebounceMs = 'HIVORR_NETWORK_DEBOUNCE_MS';

  /// Default image quality on mobile connections (`low`, `medium`, `high`).
  static const String envNetworkMobileImageQuality =
      'HIVORR_NETWORK_MOBILE_IMAGE_QUALITY';

  /// Default image quality on WiFi connections (`low`, `medium`, `high`).
  static const String envNetworkWifiImageQuality =
      'HIVORR_NETWORK_WIFI_IMAGE_QUALITY';

  /// Default pagination page size on mobile connections.
  static const String envNetworkMobilePageSize =
      'HIVORR_NETWORK_MOBILE_PAGE_SIZE';

  /// Default pagination page size on WiFi connections.
  static const String envNetworkWifiPageSize = 'HIVORR_NETWORK_WIFI_PAGE_SIZE';

  /// Advisory maximum upload size in MB on mobile connections.
  static const String envNetworkMaxUploadMbMobile =
      'HIVORR_NETWORK_MAX_UPLOAD_MB_MOBILE';

  /// Advisory maximum upload size in MB on WiFi connections.
  static const String envNetworkMaxUploadMbWifi =
      'HIVORR_NETWORK_MAX_UPLOAD_MB_WIFI';

  /// Feature flag: enables payload optimization advisories.
  static const String featureEnablePayloadOptimization =
      'HIVORR_FEATURE_ENABLE_PAYLOAD_OPTIMIZATION';

  /// Feature flag: enables the push notification receiver (Supabase Realtime).
  static const String featureEnablePushNotifications =
      'HIVORR_FEATURE_ENABLE_PUSH_NOTIFICATIONS';

  /// Feature flag: routes escrow write actions through the Edge Function
  /// proxy (`financial-escrow-proxy`). Default `false` — EP-02-08 owns the
  /// proxy deploy (EP-02-14 §5.8).
  static const String featureEscrowWriteViaProxyEnabled =
      'HIVORR_FEATURE_ESCROW_WRITE_VIA_PROXY';

  /// Feature flag: enables wallet currency conversion (EP-02-15). Default
  /// `false` — gates pair discovery, the `/finance/convert` route, and the
  /// conversion screen.
  static const String featureConversionPairsEnabled =
      'HIVORR_FEATURE_CONVERSION_PAIRS_ENABLED';

  /// Feature flag: enables the `financial_conversions` REST history read seam
  /// (EP-02-15 §5.2). Default `false` — when off, `getHistory()` returns `[]`
  /// with the future `financial_conversions_list` RPC swap point documented.
  static const String featureConversionHistoryReadEnabled =
      'HIVORR_FEATURE_CONVERSION_HISTORY_READ';

  /// Default connectivity change debounce (0 = no debounce).
  static const int defaultNetworkDebounceMs = 0;

  /// Default image quality on mobile connections.
  static const String defaultNetworkMobileImageQuality = 'low';

  /// Default image quality on WiFi connections.
  static const String defaultNetworkWifiImageQuality = 'medium';

  /// Default pagination page size on mobile connections.
  static const int defaultNetworkMobilePageSize = 15;

  /// Default pagination page size on WiFi connections.
  static const int defaultNetworkWifiPageSize = 30;

  /// Default advisory maximum upload size in MB on mobile connections.
  static const double defaultNetworkMaxUploadMbMobile = 5.0;

  /// Default advisory maximum upload size in MB on WiFi connections.
  static const double defaultNetworkMaxUploadMbWifi = 25.0;

  // ─── Monitoring configuration (EP-01-14) ──────────────────────────

  /// Sentry project DSN.
  static const String envMonitoringSentryDsn = 'HIVORR_MONITORING_SENTRY_DSN';

  /// Sentry environment tag (`development`, `staging`, `production`).
  static const String envMonitoringEnvironment =
      'HIVORR_MONITORING_ENVIRONMENT';

  /// Sentry release tag (app version).
  static const String envMonitoringRelease = 'HIVORR_MONITORING_RELEASE';

  /// Performance trace sample rate (0.0–1.0).
  static const String envMonitoringTraceSampleRate =
      'HIVORR_MONITORING_TRACE_SAMPLE_RATE';

  /// Profiling sample rate (0.0–1.0).
  static const String envMonitoringProfileSampleRate =
      'HIVORR_MONITORING_PROFILE_SAMPLE_RATE';

  /// Master enable for the Sentry SDK.
  static const String envMonitoringEnableSentry =
      'HIVORR_MONITORING_ENABLE_SENTRY';

  /// Minimum log level name.
  static const String envMonitoringMinLogLevel =
      'HIVORR_MONITORING_MIN_LOG_LEVEL';

  /// Master enable for PII redaction.
  static const String envMonitoringEnablePiiRedaction =
      'HIVORR_MONITORING_ENABLE_PII_REDACTION';

  /// Maximum breadcrumbs retained by the Sentry SDK.
  static const String envMonitoringMaxBreadcrumbs =
      'HIVORR_MONITORING_MAX_BREADCRUMBS';

  /// Default Sentry environment tag.
  static const String defaultMonitoringEnvironment = 'development';

  /// Default Sentry release tag.
  static const String defaultMonitoringRelease = 'unknown';

  /// Default Sentry DSN (empty disables Sentry).
  static const String defaultMonitoringSentryDsn = '';

  /// Default performance trace sample rate.
  static const double defaultMonitoringTraceSampleRate = 0.0;

  /// Default profiling sample rate.
  static const double defaultMonitoringProfileSampleRate = 0.0;

  /// Default Sentry enable flag (disabled until explicitly enabled).
  static const bool defaultMonitoringEnableSentry = false;

  /// Default minimum log level name.
  static const String defaultMonitoringMinLogLevel = 'debug';

  /// Default PII redaction enable flag (on by default).
  static const bool defaultMonitoringEnablePiiRedaction = true;

  /// Default maximum breadcrumb count.
  static const int defaultMonitoringMaxBreadcrumbs = 100;

  // ─── Notification configuration (EP-01-18) ─────────────────────────

  /// Default Android notification channel id.
  static const String envNotificationDefaultChannelId =
      'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_ID';

  /// User-visible default channel name.
  static const String envNotificationDefaultChannelName =
      'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_NAME';

  /// Default channel description.
  static const String envNotificationDefaultChannelDesc =
      'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_DESC';

  /// Master enable for push notification reception.
  static const String envNotificationEnablePush =
      'HIVORR_NOTIFICATION_ENABLE_PUSH';

  /// Master enable for local notification dispatch.
  static const String envNotificationEnableLocal =
      'HIVORR_NOTIFICATION_ENABLE_LOCAL';

  /// Supabase Realtime channel/table name for push events.
  static const String envNotificationPushChannelName =
      'HIVORR_NOTIFICATION_PUSH_CHANNEL_NAME';

  /// Android notification small icon resource.
  static const String envNotificationIconResource =
      'HIVORR_NOTIFICATION_ICON_RESOURCE';

  /// Default notification channel id.
  static const String defaultNotificationDefaultChannelId = 'hivorr_default';

  /// Default notification channel name.
  static const String defaultNotificationDefaultChannelName =
      'Hivorr Notifications';

  /// Default notification channel description.
  static const String defaultNotificationDefaultChannelDesc =
      'General notifications from Hivorr';

  /// Default push enable flag (disabled until explicitly enabled).
  static const bool defaultNotificationEnablePush = false;

  /// Default local notification enable flag.
  static const bool defaultNotificationEnableLocal = true;

  /// Default Supabase Realtime push channel name.
  static const String defaultNotificationPushChannelName =
      'notification_events';

  /// Default Android notification icon resource.
  static const String defaultNotificationIconResource = '@mipmap/ic_launcher';

  // ─── Payment gateway configuration (EP-02-09) ───────────────────────

  /// Paystack public (publishable) key.
  static const String envPaystackPublicKey = 'HIVORR_PAYSTACK_PUBLIC_KEY';

  /// Paystack secret key — live money-movement secret, never logged.
  static const String envPaystackSecretKey = 'HIVORR_PAYSTACK_SECRET_KEY';

  /// Flutterwave public (publishable) key.
  static const String envFlutterwavePublicKey =
      'HIVORR_FLUTTERWAVE_PUBLIC_KEY';

  /// Flutterwave secret key — live money-movement secret, never logged.
  static const String envFlutterwaveSecretKey =
      'HIVORR_FLUTTERWAVE_SECRET_KEY';

  /// NIBSS name-enquiry base URL (HTTPS), when a direct credential exists.
  static const String envNibssBaseUrl = 'HIVORR_NIBSS_BASE_URL';

  /// NIBSS name-enquiry API key.
  static const String envNibssApiKey = 'HIVORR_NIBSS_API_KEY';

  /// Default payment provider selected per environment:
  /// `paystack` | `flutterwave`.
  static const String envPaymentDefaultProvider =
      'HIVORR_PAYMENT_DEFAULT_PROVIDER';

  /// Default fallback payment provider.
  static const String defaultPaymentProvider = 'paystack';

  // ─── Application identifiers ────────────────────────────────────────

  /// Human-readable application name.
  static const String applicationName = 'Hivorr';

  /// Application bundle identifier.
  static const String applicationId = 'ai.hivorr.app';
}
