import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'notification_test_helpers.dart';

HivorrNotification _n(int id) => HivorrNotification(
  id: id,
  title: 'a',
  body: 'b',
  channelId: 'hivorr_default',
  timestamp: DateTime.fromMillisecondsSinceEpoch(id),
);

void main() {
  test('initialize subscribes push when permission granted', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final push = FakePushNotificationReceiver();
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      pushReceiver: push,
      entityId: 'e1',
    );
    await provider.initialize();
    expect(provider.permissionStatus, NotificationPermissionStatus.granted);
    expect(provider.isPushSubscribed, isTrue);
    expect(push.subscribed, isTrue);
  });

  test('initialize does not subscribe push when denied', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.denied,
      canRequest: true,
    );
    final push = FakePushNotificationReceiver();
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      pushReceiver: push,
      entityId: 'e1',
    );
    await provider.initialize();
    expect(provider.permissionStatus, NotificationPermissionStatus.denied);
    expect(provider.isPushSubscribed, isFalse);
    expect(push.subscribed, isFalse);
  });

  test('requestPermission subscribes on grant', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final push = FakePushNotificationReceiver();
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      pushReceiver: push,
      entityId: 'e1',
    );
    await provider.requestPermission();
    expect(provider.isPushSubscribed, isTrue);
  });

  test('showLocal delegates to service', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      entityId: 'e1',
    );
    final n = _n(9);
    await provider.showLocal(n);
    expect(service.shown, contains(n));
  });

  test('push onMessage updates state and renders locally', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final push = FakePushNotificationReceiver();
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      pushReceiver: push,
      entityId: 'e1',
    );
    await provider.initialize();
    final n = _n(11);
    push.emitMessage(n);
    await Future<void>.delayed(Duration.zero);
    expect(provider.lastNotification, n);
    expect(provider.pendingCount, 1);
    expect(service.shown, contains(n));
  });

  test('tap decrements pending count', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final push = FakePushNotificationReceiver();
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      pushReceiver: push,
      entityId: 'e1',
    );
    await provider.initialize();
    final n = _n(12);
    push.emitMessage(n);
    await Future<void>.delayed(Duration.zero);
    expect(provider.pendingCount, 1);
    service.emitTap(n);
    await Future<void>.delayed(Duration.zero);
    expect(provider.pendingCount, 0);
  });

  test('dispose unsubscribes push and disposes service', () async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final push = FakePushNotificationReceiver();
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
      pushReceiver: push,
      entityId: 'e1',
    );
    await provider.initialize();
    provider.dispose();
    expect(push.disposed, isTrue);
  });
}
