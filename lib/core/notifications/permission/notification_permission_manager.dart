import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';

/// Platform abstraction for notification permission state.
///
/// The default [FlutterLocalNotificationsPermissionPlatform] wraps
/// `flutter_local_notifications`. Tests inject a fake to verify delegation
/// and the permanently-denied state (EP-01-18 §14.9).
abstract class NotificationPermissionPlatform {
  /// Returns the current permission status.
  Future<NotificationPermissionStatus> checkStatus();

  /// Requests permission from the user.
  Future<NotificationPermissionStatus> requestPermission();

  /// Whether permission can still be requested (false when permanently denied).
  bool get canRequestPermission;
}

/// Default [NotificationPermissionPlatform] backed by the plugin.
class FlutterLocalNotificationsPermissionPlatform
    implements NotificationPermissionPlatform {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<NotificationPermissionStatus> checkStatus() async {
    // The plugin does not expose a reliable cross-platform query. Consumers
    // request and derive the actual status; we report notDetermined so the
    // UI can prompt. Best-effort for a foundation (EP-01-18 §5.13).
    return NotificationPermissionStatus.notDetermined;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (androidGranted != null) {
      return androidGranted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (iosGranted != null) {
      return iosGranted
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    // Web or unsupported platform: cannot determine without a prompt.
    return NotificationPermissionStatus.notDetermined;
  }

  @override
  bool get canRequestPermission => true;
}

/// Queries and requests notification permissions with graceful degradation.
///
/// Local notifications continue to function when push permission is denied;
/// only push subscription is suppressed by the [NotificationProvider]. No
/// notification is ever delivered without an explicit grant (AGENT.md Rule 4).
class NotificationPermissionManager {
  /// Creates the permission manager.
  ///
  /// [platform] defaults to [FlutterLocalNotificationsPermissionPlatform];
  /// inject a fake in tests.
  NotificationPermissionManager({NotificationPermissionPlatform? platform})
    : _platform = platform ?? FlutterLocalNotificationsPermissionPlatform();

  final NotificationPermissionPlatform _platform;
  NotificationPermissionStatus _status =
      NotificationPermissionStatus.notDetermined;

  /// The last observed permission status.
  NotificationPermissionStatus get status => _status;

  /// Queries the current permission status.
  Future<NotificationPermissionStatus> checkStatus() async {
    _status = await _platform.checkStatus();
    return _status;
  }

  /// Requests permission and returns the resulting status.
  Future<NotificationPermissionStatus> requestPermission() async {
    _status = await _platform.requestPermission();
    return _status;
  }

  /// Whether permission can still be requested.
  ///
  /// False once granted or permanently denied.
  bool get canRequestPermission =>
      _platform.canRequestPermission &&
      _status != NotificationPermissionStatus.granted &&
      _status != NotificationPermissionStatus.permanentlyDenied;
}
