import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hivorr/core/logging/logging.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_channel.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/notification_config.dart';
import 'package:hivorr/core/notifications/services/notification_service.dart';

/// Platform abstraction for local notification rendering.
///
/// The default [FlutterLocalNotificationsBackend] wraps the
/// `flutter_local_notifications` plugin. The seam exists so unit tests can
/// inject a fake backend and verify delegation without a device (EP-01-18 §14.6).
abstract class LocalNotificationBackend {
  /// Initializes platform-specific settings.
  ///
  /// [onNotificationTapped] is invoked when the user taps a notification.
  Future<bool?> initialize({
    required void Function(String? payload) onNotificationTapped,
  });

  /// Renders a notification with the given platform [details].
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  });

  /// Cancels the notification with [id].
  Future<void> cancel(int id);

  /// Cancels all notifications.
  Future<void> cancelAll();

  /// Returns the pending (un-cancelled) notification requests.
  Future<List<PendingNotificationRequest>> pendingNotificationRequests();

  /// Creates an Android notification channel (no-op on other platforms).
  Future<void> createAndroidChannel(AndroidNotificationChannel channel);

  /// Deletes an Android notification channel (no-op on other platforms).
  Future<void> deleteAndroidChannel(String channelId);

  /// Requests the Android 13+ POST_NOTIFICATIONS permission.
  Future<bool?> requestAndroidPermission();

  /// Requests iOS alert/badge/sound permissions.
  Future<bool?> requestIOSPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  });
}

/// Default [LocalNotificationBackend] backed by `flutter_local_notifications`.
class FlutterLocalNotificationsBackend implements LocalNotificationBackend {
  /// Creates a backend configured from [config] (used for the Android icon).
  FlutterLocalNotificationsBackend(this._config);

  final NotificationConfig _config;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<bool?> initialize({
    required void Function(String? payload) onNotificationTapped,
  }) {
    final android = AndroidInitializationSettings(
      _config.notificationIconResource,
    );
    const darwin = DarwinInitializationSettings();
    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    return _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTapped(response.payload);
      },
    );
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  }) => _plugin.show(id, title, body, details, payload: payload);

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      _plugin.pendingNotificationRequests();

  @override
  Future<void> createAndroidChannel(AndroidNotificationChannel channel) async {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await impl?.createNotificationChannel(channel);
  }

  @override
  Future<void> deleteAndroidChannel(String channelId) async {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await impl?.deleteNotificationChannel(channelId);
  }

  @override
  Future<bool?> requestAndroidPermission() {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return impl?.requestNotificationsPermission() ?? Future<bool?>.value(null);
  }

  @override
  Future<bool?> requestIOSPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  }) {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return impl?.requestPermissions(alert: alert, badge: badge, sound: sound) ??
        Future<bool?>.value(null);
  }
}

/// Concrete [NotificationService] backed by `flutter_local_notifications`.
class LocalNotificationService implements NotificationService {
  /// Creates the local notification service.
  ///
  /// [backend] defaults to [FlutterLocalNotificationsBackend]; inject a fake
  /// in tests. [knownChannels] lets the service resolve channel names and
  /// importance when rendering (populated by [NotificationChannelManager]).
  LocalNotificationService(
    this._config, {
    LocalNotificationBackend? backend,
    this.logger,
    Map<String, NotificationChannel>? knownChannels,
  }) : _backend = backend ?? FlutterLocalNotificationsBackend(_config),
       _knownChannels = knownChannels ?? <String, NotificationChannel>{};

  final NotificationConfig _config;
  final LocalNotificationBackend _backend;
  final HivorrLogger? logger;
  final Map<String, NotificationChannel> _knownChannels;

  final StreamController<HivorrNotification> _tapController =
      StreamController<HivorrNotification>.broadcast();

  bool _initialized = false;

  @override
  Stream<HivorrNotification> get onNotificationTapped => _tapController.stream;

  @override
  Future<void> initialize() async {
    await _backend.initialize(
      onNotificationTapped: (String? payload) {
        final notification = _parsePayload(payload);
        if (notification != null) {
          _tapController.add(notification);
        }
      },
    );
    _initialized = true;
  }

  /// Whether [initialize] has completed.
  bool get isInitialized => _initialized;

  @override
  Future<void> show(HivorrNotification notification) async {
    if (!_config.enableLocalNotifications) return;
    final details = _buildDetails(notification);
    await _backend.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      details: details,
      payload: jsonEncode(notification.toJson()),
    );
  }

  @override
  Future<void> cancel(int id) => _backend.cancel(id);

  @override
  Future<void> cancelAll() => _backend.cancelAll();

  @override
  Future<List<HivorrNotification>> getPendingNotifications() async {
    final requests = await _backend.pendingNotificationRequests();
    return requests.map(_mapPending).toList();
  }

  HivorrNotification _mapPending(PendingNotificationRequest request) {
    final parsed = _parsePayload(request.payload);
    if (parsed != null) return parsed;
    return HivorrNotification(
      id: request.id,
      title: request.title ?? '',
      body: request.body ?? '',
      channelId: _config.defaultChannelId,
      timestamp: DateTime.now(),
    );
  }

  HivorrNotification? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        return HivorrNotification.fromJson(data);
      }
      return null;
    } on Object catch (e) {
      logger?.warning(
        'Failed to parse notification tap payload',
        <String, Object?>{'error': e.toString()},
      );
      return null;
    }
  }

  NotificationDetails _buildDetails(HivorrNotification notification) {
    final channel = _knownChannels[notification.channelId];
    final androidImportance = _toAndroidImportance(notification.priority);
    final androidPriority = _toAndroidPriority(notification.priority);
    final android = AndroidNotificationDetails(
      notification.channelId,
      channel?.name ?? notification.channelId,
      channelDescription: channel?.description,
      importance: androidImportance,
      priority: androidPriority,
      playSound: channel?.enableSound ?? true,
      enableVibration: channel?.enableVibration ?? true,
      enableLights: channel?.enableLed ?? false,
      ledColor: channel?.ledColor == null ? null : Color(channel!.ledColor!),
    );

    final present = notification.priority != NotificationPriority.low;
    final darwin = DarwinNotificationDetails(
      presentAlert: present,
      presentBadge:
          notification.priority == NotificationPriority.high ||
          notification.priority == NotificationPriority.urgent,
      presentSound: present,
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  static Importance _toAndroidImportance(NotificationPriority priority) {
    return switch (priority) {
      NotificationPriority.low => Importance.low,
      NotificationPriority.normal => Importance.defaultImportance,
      NotificationPriority.high => Importance.high,
      NotificationPriority.urgent => Importance.max,
    };
  }

  static Priority _toAndroidPriority(NotificationPriority priority) {
    return switch (priority) {
      NotificationPriority.low => Priority.low,
      NotificationPriority.normal => Priority.defaultPriority,
      NotificationPriority.high => Priority.high,
      NotificationPriority.urgent => Priority.max,
    };
  }

  @override
  void dispose() {
    if (!_tapController.isClosed) {
      unawaited(_tapController.close());
    }
  }
}
