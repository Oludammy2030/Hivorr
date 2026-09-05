import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Centrally declared, strongly typed feature flags.
///
/// Flags are parsed with strict boolean rules (`true` or `false` only),
/// disabled by default when absent, explicitly controlled per environment,
/// and free of business logic and remote-fetch behavior (EP-01-03 §5.6).
///
/// No flag silently enables experimental behavior in Production.
class FeatureFlags {
  const FeatureFlags({
    required this.enableVerboseLogging,
    required this.enableOfflineSync,
    required this.enableAnalyticsTracking,
    required this.enableDynamicWorkspaceLoading,
    required this.enablePayloadOptimization,
    required this.enablePushNotifications,
    this.escrowWriteViaProxyEnabled = false,
  });

  /// Whether verbose structured logging is enabled.
  ///
  /// Safe default: `false`. Enable only in Development or Staging.
  final bool enableVerboseLogging;

  /// Whether the offline sync engine is enabled.
  ///
  /// Safe default: `false`. Enable per environment as the sync engine
  /// is rolled out (EP-01-12).
  final bool enableOfflineSync;

  /// Whether analytics tracking is enabled.
  ///
  /// Safe default: `false`. Enable per environment after the analytics
  /// infrastructure is established (EP-01-14).
  final bool enableAnalyticsTracking;

  /// Whether dynamic workspace module loading is enabled.
  ///
  /// Safe default: `false`. Enable per environment after the workspace
  /// loader is implemented (EP-01-15+).
  final bool enableDynamicWorkspaceLoading;

  /// Whether payload optimization advisories are enabled.
  ///
  /// Safe default: `false`. Enable per environment after the network
  /// management layer is rolled out (EP-01-13).
  final bool enablePayloadOptimization;

  /// Whether push notification reception is enabled.
  ///
  /// Safe default: `false`. Enable per environment after the push
  /// transport (Supabase Realtime) is provisioned for that environment
  /// (EP-01-18). Gated together with [NotificationConfig.enablePushNotifications].
  final bool enablePushNotifications;

  /// Whether escrow write actions route through the Edge Function proxy.
  ///
  /// Safe default: `false` in all environments until the EP-02-18 proxy
  /// (`financial-escrow-proxy`) is deployed. When `false`, escrow write calls
  /// surface [EscrowWriteUnavailableException] guidance (EP-02-14 §5.8).
  final bool escrowWriteViaProxyEnabled;

  /// Parses feature flags from [source] using strict boolean rules.
  ///
  /// Accepted values are exactly `true` or `false` (case-sensitive).
  /// Malformed values cause [EnvironmentConfigException].
  /// Absent variables default to `false` — safe disabled-by-default.
  static FeatureFlags fromSource(EnvironmentValueSource source) {
    return FeatureFlags(
      enableVerboseLogging: _parseBool(
        source,
        AppConstants.featureEnableVerboseLogging,
      ),
      enableOfflineSync: _parseBool(
        source,
        AppConstants.featureEnableOfflineSync,
      ),
      enableAnalyticsTracking: _parseBool(
        source,
        AppConstants.featureEnableAnalyticsTracking,
      ),
      enableDynamicWorkspaceLoading: _parseBool(
        source,
        AppConstants.featureEnableDynamicWorkspaceLoading,
      ),
      enablePayloadOptimization: _parseBool(
        source,
        AppConstants.featureEnablePayloadOptimization,
      ),
      enablePushNotifications: _parseBool(
        source,
        AppConstants.featureEnablePushNotifications,
      ),
      escrowWriteViaProxyEnabled: _parseBool(
        source,
        AppConstants.featureEscrowWriteViaProxyEnabled,
      ),
    );
  }

  /// Returns `false` when the variable is absent (safe default).
  /// Throws [EnvironmentConfigException] for malformed values.
  static bool _parseBool(EnvironmentValueSource source, String key) {
    final raw = source.read(key);
    if (raw == null) {
      return false;
    }
    return switch (raw) {
      'true' => true,
      'false' => false,
      _ => throw EnvironmentConfigException(
        variableName: key,
        reason: 'Malformed feature-flag value. Accepted values: true, false.',
      ),
    };
  }

  @override
  String toString() {
    return 'FeatureFlags('
        'enableVerboseLogging: $enableVerboseLogging, '
        'enableOfflineSync: $enableOfflineSync, '
        'enableAnalyticsTracking: $enableAnalyticsTracking, '
        'enableDynamicWorkspaceLoading: $enableDynamicWorkspaceLoading, '
        'enablePayloadOptimization: $enablePayloadOptimization, '
        'enablePushNotifications: $enablePushNotifications, '
        'escrowWriteViaProxyEnabled: $escrowWriteViaProxyEnabled)';
  }
}
