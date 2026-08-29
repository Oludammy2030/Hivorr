import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hivorr/core/logging/logging.dart';
import 'package:hivorr/core/notifications/models/notification_channel.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/notification_config.dart';
import 'package:hivorr/core/notifications/services/local_notification_service.dart';

/// Manages Android notification channel lifecycle.
///
/// Channels are an Android-only concept; on iOS and Web every method is a
/// no-op (guarded by the platform-specific backend). Channel ids are validated
/// (alphanumeric + underscore) before creation to prevent arbitrary channel
/// identifier injection (EP-01-18 §12).
class NotificationChannelManager {
  /// Creates the channel manager.
  ///
  /// [backend] defaults to [FlutterLocalNotificationsBackend]; inject a fake
  /// in tests. [logger] is optional.
  NotificationChannelManager(this._backend, {this.logger});

  final LocalNotificationBackend _backend;
  final HivorrLogger? logger;

  final Map<String, NotificationChannel> _channels =
      <String, NotificationChannel>{};

  /// Read-only view of the channels created so far.
  Map<String, NotificationChannel> get channels =>
      Map<String, NotificationChannel>.unmodifiable(_channels);

  /// Creates the app's default channel using [config] values.
  Future<void> createDefaultChannel(NotificationConfig config) => createChannel(
    NotificationChannel(
      id: config.defaultChannelId,
      name: config.defaultChannelName,
      description: config.defaultChannelDescription,
      importance: NotificationPriority.normal,
    ),
  );

  /// Creates a custom notification channel.
  Future<void> createChannel(NotificationChannel channel) async {
    if (!_isValidChannelId(channel.id)) {
      logger?.warning(
        'Rejected invalid notification channel id (allowed: [a-zA-Z0-9_])',
        <String, Object?>{'channelId': channel.id},
      );
      return;
    }
    final androidChannel = AndroidNotificationChannel(
      channel.id,
      channel.name,
      description: channel.description,
      importance: _toAndroidImportance(channel.importance),
    );
    await _backend.createAndroidChannel(androidChannel);
    _channels[channel.id] = channel;
  }

  /// Removes a previously created channel.
  Future<void> deleteChannel(String channelId) async {
    if (!_isValidChannelId(channelId)) return;
    await _backend.deleteAndroidChannel(channelId);
    _channels.remove(channelId);
  }

  static bool _isValidChannelId(String channelId) {
    if (channelId.isEmpty) return false;
    // Restrict to safe characters; non-Android platforms ignore channels.
    final RegExp allowed = RegExp(r'^[a-zA-Z0-9_]+$');
    return allowed.hasMatch(channelId);
  }

  static Importance _toAndroidImportance(NotificationPriority priority) {
    return switch (priority) {
      NotificationPriority.low => Importance.low,
      NotificationPriority.normal => Importance.defaultImportance,
      NotificationPriority.high => Importance.high,
      NotificationPriority.urgent => Importance.max,
    };
  }
}
