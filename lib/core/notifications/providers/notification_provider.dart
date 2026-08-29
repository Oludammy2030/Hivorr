import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hivorr/core/logging/logging.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/push/push_notification_receiver.dart';
import 'package:hivorr/core/notifications/services/notification_service.dart';

/// Propagates notification state to the widget tree.
///
/// Exposes [permissionStatus], [pendingCount], [lastNotification], and
/// [isPushSubscribed] for UI (badge counts, settings screens, prompts). It
/// bridges the push receiver to local rendering and tracks tap-driven state
/// changes (EP-01-18 §5.14).
class NotificationProvider extends ChangeNotifier {
  /// Creates the notification provider.
  ///
  /// [entityId] is required for push subscription. [logger] is optional.
  NotificationProvider(
    this._service,
    this._permissionManager, {
    this.pushReceiver,
    this.entityId,
    this.logger,
  });

  final NotificationService _service;
  final NotificationPermissionManager _permissionManager;
  final PushNotificationReceiver? pushReceiver;
  final String? entityId;
  final HivorrLogger? logger;

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;
  int _pendingCount = 0;
  HivorrNotification? _lastNotification;
  bool _isPushSubscribed = false;
  String? _lastError;
  bool _disposed = false;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  /// Current notification permission state.
  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  /// Number of pending (unread) notifications.
  int get pendingCount => _pendingCount;

  /// Most recently received notification.
  HivorrNotification? get lastNotification => _lastNotification;

  /// Whether the push receiver is actively subscribed.
  bool get isPushSubscribed => _isPushSubscribed;

  /// Most recent error message, if any.
  String? get lastError => _lastError;

  /// Initializes permission state and, if granted, push subscription.
  Future<void> initialize() async {
    _permissionStatus = await _permissionManager.checkStatus();
    if (_canSubscribePush(_permissionStatus)) {
      await _subscribePush();
    }
    _listen();
    notifyListeners();
  }

  /// Requests permission, updates state, and subscribes if granted.
  Future<void> requestPermission() async {
    _permissionStatus = await _permissionManager.requestPermission();
    if (_canSubscribePush(_permissionStatus)) {
      await _subscribePush();
    } else {
      _isPushSubscribed = false;
    }
    notifyListeners();
  }

  /// Dispatches a local notification through the service.
  Future<void> showLocal(HivorrNotification notification) async {
    try {
      await _service.show(notification);
    } on Object catch (e) {
      _lastError = e.toString();
      logger?.warning('Failed to show local notification', <String, Object?>{
        'error': e.toString(),
      });
    }
  }

  /// Cancels the notification with [id].
  Future<void> cancelNotification(int id) => _service.cancel(id);

  /// Cancels all notifications.
  Future<void> cancelAll() => _service.cancelAll();

  bool _canSubscribePush(NotificationPermissionStatus status) =>
      status == NotificationPermissionStatus.granted &&
      pushReceiver != null &&
      entityId != null;

  Future<void> _subscribePush() async {
    try {
      await pushReceiver!.subscribe(entityId!);
      _isPushSubscribed = pushReceiver!.isSubscribed;
    } on Object catch (e) {
      _lastError = e.toString();
      _isPushSubscribed = false;
      logger?.warning(
        'Failed to subscribe push notifications',
        <String, Object?>{'error': e.toString()},
      );
    }
  }

  void _listen() {
    final receiver = pushReceiver;
    if (receiver != null) {
      _subscriptions.add(receiver.onMessage.listen(_handlePushMessage));
    }
    _subscriptions.add(_service.onNotificationTapped.listen(_handleTap));
  }

  void _handlePushMessage(HivorrNotification notification) {
    // Render locally and surface in provider state (EP-01-18 §5.12).
    unawaited(_service.show(notification));
    _lastNotification = notification;
    _pendingCount += 1;
    if (!_disposed) notifyListeners();
  }

  void _handleTap(HivorrNotification notification) {
    _lastNotification = notification;
    if (_pendingCount > 0) _pendingCount -= 1;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    if (pushReceiver != null) {
      pushReceiver!.dispose();
    }
    super.dispose();
  }
}
