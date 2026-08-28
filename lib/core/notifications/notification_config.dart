import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Immutable notification engine configuration.
///
/// Every value is sourced exclusively from [EnvironmentConfig] (via the
/// compile-time defines in EP-01-03); nothing here is a hardcoded secret or
/// literal. Push is disabled unless both [enablePushNotifications] and the
/// global [FeatureFlags.enablePushNotifications] are true (fail-closed).
class NotificationConfig {
  const NotificationConfig({
    required this.defaultChannelId,
    required this.defaultChannelName,
    required this.defaultChannelDescription,
    required this.enablePushNotifications,
    required this.enableLocalNotifications,
    required this.pushChannelName,
    required this.notificationIconResource,
  });

  /// Default Android notification channel id.
  final String defaultChannelId;

  /// Default channel user-visible name.
  final String defaultChannelName;

  /// Default channel description.
  final String defaultChannelDescription;

  /// Master enable for push notification reception.
  final bool enablePushNotifications;

  /// Master enable for local notification dispatch.
  final bool enableLocalNotifications;

  /// Supabase Realtime channel/table name for push events.
  final String pushChannelName;

  /// Android notification small icon resource.
  final String notificationIconResource;

  /// Builds [NotificationConfig] from an [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults so the loader stays fail-closed
  /// on the core Supabase/schema contract while notifications remain opt-in
  /// per environment (EP-01-18 §5.7).
  static NotificationConfig fromSource(EnvironmentValueSource source) {
    final defaultChannelId =
        source.read(AppConstants.envNotificationDefaultChannelId) ??
        AppConstants.defaultNotificationDefaultChannelId;
    final defaultChannelName =
        source.read(AppConstants.envNotificationDefaultChannelName) ??
        AppConstants.defaultNotificationDefaultChannelName;
    final defaultChannelDescription =
        source.read(AppConstants.envNotificationDefaultChannelDesc) ??
        AppConstants.defaultNotificationDefaultChannelDesc;
    final pushChannelName =
        source.read(AppConstants.envNotificationPushChannelName) ??
        AppConstants.defaultNotificationPushChannelName;
    final notificationIconResource =
        source.read(AppConstants.envNotificationIconResource) ??
        AppConstants.defaultNotificationIconResource;
    final enablePushNotifications = _parseBool(
      source,
      AppConstants.envNotificationEnablePush,
      AppConstants.defaultNotificationEnablePush,
    );
    final enableLocalNotifications = _parseBool(
      source,
      AppConstants.envNotificationEnableLocal,
      AppConstants.defaultNotificationEnableLocal,
    );

    return NotificationConfig(
      defaultChannelId: defaultChannelId,
      defaultChannelName: defaultChannelName,
      defaultChannelDescription: defaultChannelDescription,
      enablePushNotifications: enablePushNotifications,
      enableLocalNotifications: enableLocalNotifications,
      pushChannelName: pushChannelName,
      notificationIconResource: notificationIconResource,
    );
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
        reason: 'Malformed notification flag. Accepted values: true, false.',
      ),
    };
  }

  @override
  String toString() {
    return 'NotificationConfig('
        'defaultChannelId: $defaultChannelId, '
        'enablePushNotifications: $enablePushNotifications, '
        'enableLocalNotifications: $enableLocalNotifications, '
        'pushChannelName: $pushChannelName)';
  }
}
