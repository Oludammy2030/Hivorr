import 'dart:async';

import 'package:hivorr/core/notifications/models/hivorr_notification.dart';

/// Unified, transport-agnostic notification dispatch contract.
///
/// Implementations render notifications on the device (local) and may delegate
/// to a platform plugin. The interface is deliberately abstract so alternative
/// delivery backends (e.g. an in-app toast system) can be added without
/// changing consumers (EP-01-18 §5.8, §5.19).
abstract class NotificationService {
  /// Initializes the underlying platform notification machinery.
  Future<void> initialize();

  /// Displays [notification] to the user.
  Future<void> show(HivorrNotification notification);

  /// Cancels the notification with the given [id].
  Future<void> cancel(int id);

  /// Cancels all notifications dispatched by this service.
  Future<void> cancelAll();

  /// Returns the list of currently pending (un-cancelled) notifications.
  Future<List<HivorrNotification>> getPendingNotifications();

  /// Stream of notifications the user tapped (foreground + background launch).
  Stream<HivorrNotification> get onNotificationTapped;

  /// Releases resources held by the service.
  void dispose();
}
