import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/notification_config.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/push/push_notification_receiver.dart';
import 'package:hivorr/core/notifications/services/local_notification_service.dart';
import 'package:hivorr/core/notifications/services/notification_service.dart';

/// Records a single [LocalNotificationBackend.show] invocation.
class ShowCall {
  ShowCall(this.id, this.title, this.body, this.details, this.payload);
  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
  final String? payload;
}

/// Fake [LocalNotificationBackend] recording every delegated call.
class FakeLocalNotificationBackend implements LocalNotificationBackend {
  void Function(String?)? capturedOnTap;
  bool initializeCalled = false;
  final List<ShowCall> showCalls = <ShowCall>[];
  final List<AndroidNotificationChannel> createdChannels =
      <AndroidNotificationChannel>[];
  final List<String> deletedChannels = <String>[];
  List<PendingNotificationRequest> pending = <PendingNotificationRequest>[];
  bool? androidPermissionResult;
  bool? iosPermissionResult;

  @override
  Future<bool?> initialize({
    required void Function(String?) onNotificationTapped,
  }) {
    initializeCalled = true;
    capturedOnTap = onNotificationTapped;
    return Future<bool?>.value(true);
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  }) {
    showCalls.add(ShowCall(id, title, body, details, payload));
    return Future<void>.value();
  }

  @override
  Future<void> cancel(int id) => Future<void>.value();

  @override
  Future<void> cancelAll() => Future<void>.value();

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      Future<List<PendingNotificationRequest>>.value(pending);

  @override
  Future<void> createAndroidChannel(AndroidNotificationChannel channel) {
    createdChannels.add(channel);
    return Future<void>.value();
  }

  @override
  Future<void> deleteAndroidChannel(String channelId) {
    deletedChannels.add(channelId);
    return Future<void>.value();
  }

  @override
  Future<bool?> requestAndroidPermission() =>
      Future<bool?>.value(androidPermissionResult);

  @override
  Future<bool?> requestIOSPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  }) => Future<bool?>.value(iosPermissionResult);
}

/// Fake [NotificationPermissionPlatform] with canned responses.
class FakeNotificationPermissionPlatform
    implements NotificationPermissionPlatform {
  FakeNotificationPermissionPlatform({
    this.nextStatus = NotificationPermissionStatus.notDetermined,
    this.canRequest = true,
  });

  NotificationPermissionStatus nextStatus;
  bool canRequest;

  @override
  Future<NotificationPermissionStatus> checkStatus() =>
      Future<NotificationPermissionStatus>.value(nextStatus);

  @override
  Future<NotificationPermissionStatus> requestPermission() =>
      Future<NotificationPermissionStatus>.value(nextStatus);

  @override
  bool get canRequestPermission => canRequest;
}

/// Fake [PushRealtimeGateway] recording subscription requests.
class FakePushRealtimeGateway implements PushRealtimeGateway {
  String? subscribedEntityId;
  String? subscribedChannel;
  bool unsubscribed = false;
  int subscribeCallCount = 0;
  void Function(Map<String, dynamic> payload)? _onEvent;

  @override
  Future<void> subscribe({
    required String channelName,
    required String entityId,
    required void Function(Map<String, dynamic> payload) onEvent,
  }) {
    subscribeCallCount += 1;
    subscribedChannel = channelName;
    subscribedEntityId = entityId;
    _onEvent = onEvent;
    return Future<void>.value();
  }

  void emitEvent(Map<String, dynamic> payload) => _onEvent?.call(payload);

  @override
  Future<void> unsubscribe() {
    unsubscribed = true;
    subscribedEntityId = null;
    subscribedChannel = null;
    return Future<void>.value();
  }
}

/// Fake [PushNotificationReceiver] with controllable streams.
class FakePushNotificationReceiver implements PushNotificationReceiver {
  final StreamController<HivorrNotification> _message =
      StreamController<HivorrNotification>.broadcast();
  bool subscribed = false;
  bool disposed = false;

  @override
  Future<void> subscribe(String entityId) async => subscribed = true;

  @override
  Future<void> unsubscribe() async => subscribed = false;

  @override
  Stream<HivorrNotification> get onMessage => _message.stream;

  @override
  Stream<HivorrNotification> get onBackgroundMessage =>
      const Stream<HivorrNotification>.empty();

  @override
  bool get isSubscribed => subscribed;

  void emitMessage(HivorrNotification notification) =>
      _message.add(notification);

  @override
  void dispose() {
    disposed = true;
    if (!_message.isClosed) unawaited(_message.close());
  }
}

/// Fake [NotificationService] recording dispatches and exposing tap events.
class FakeNotificationService implements NotificationService {
  final StreamController<HivorrNotification> _tap =
      StreamController<HivorrNotification>.broadcast();
  final List<HivorrNotification> shown = <HivorrNotification>[];
  bool initializeCalled = false;
  bool disposed = false;

  @override
  Future<void> initialize() async => initializeCalled = true;

  @override
  Future<void> show(HivorrNotification notification) async =>
      shown.add(notification);

  @override
  Future<void> cancel(int id) => Future<void>.value();

  @override
  Future<void> cancelAll() => Future<void>.value();

  @override
  Future<List<HivorrNotification>> getPendingNotifications() =>
      Future<List<HivorrNotification>>.value(<HivorrNotification>[]);

  @override
  Stream<HivorrNotification> get onNotificationTapped => _tap.stream;

  void emitTap(HivorrNotification notification) => _tap.add(notification);

  @override
  void dispose() {
    disposed = true;
    if (!_tap.isClosed) unawaited(_tap.close());
  }
}

/// Builds a [NotificationConfig] from overrides, filling safe defaults.
NotificationConfig buildConfig([Map<String, String>? overrides]) {
  final source = MapEnvironmentValueSource(<String, String>{...?overrides});
  return NotificationConfig.fromSource(source);
}

/// Example serialized notification payload for tap round-trips.
String exampleTapPayload() => jsonEncode(
  HivorrNotification(
    id: 1,
    title: 't',
    body: 'b',
    channelId: 'hivorr_default',
    priority: NotificationPriority.high,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  ).toJson(),
);
