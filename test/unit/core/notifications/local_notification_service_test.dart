import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/services/local_notification_service.dart';
import 'notification_test_helpers.dart';

HivorrNotification _n(int id) => HivorrNotification(
      id: id,
      title: 'Title $id',
      body: 'Body',
      channelId: 'hivorr_default',
      priority: NotificationPriority.normal,
      timestamp: DateTime.fromMillisecondsSinceEpoch(id),
    );

void main() {
  test('initialize delegates to backend and toggles state', () async {
    final backend = FakeLocalNotificationBackend();
    final service = LocalNotificationService(buildConfig(), backend: backend);
    await service.initialize();
    expect(backend.initializeCalled, isTrue);
    expect(service.isInitialized, isTrue);
  });

  test('show delegates with serialized JSON payload', () async {
    final backend = FakeLocalNotificationBackend();
    final service = LocalNotificationService(buildConfig(), backend: backend);
    await service.initialize();
    final n = _n(7);
    await service.show(n);
    expect(backend.showCalls, hasLength(1));
    expect(backend.showCalls.first.id, 7);
    expect(backend.showCalls.first.title, 'Title 7');
    final decoded =
        jsonDecode(backend.showCalls.first.payload!) as Map<String, dynamic>;
    expect(decoded['id'], 7);
  });

  test('show is a no-op when local notifications disabled', () async {
    final backend = FakeLocalNotificationBackend();
    final service = LocalNotificationService(
      buildConfig({'HIVORR_NOTIFICATION_ENABLE_LOCAL': 'false'}),
      backend: backend,
    );
    await service.initialize();
    await service.show(_n(1));
    expect(backend.showCalls, isEmpty);
  });

  test('getPendingNotifications maps pending requests', () async {
    final backend = FakeLocalNotificationBackend();
    backend.pending = [
      PendingNotificationRequest(
        3,
        'p',
        'b',
        jsonEncode(HivorrNotification(
          id: 3,
          title: 'p',
          body: 'b',
          channelId: 'hivorr_default',
          priority: NotificationPriority.normal,
          timestamp: DateTime.fromMillisecondsSinceEpoch(3),
        ).toJson()),
      ),
    ];
    final service = LocalNotificationService(buildConfig(), backend: backend);
    final list = await service.getPendingNotifications();
    expect(list, hasLength(1));
    expect(list.first.id, 3);
  });

  test('onNotificationTapped emits parsed notification', () async {
    final backend = FakeLocalNotificationBackend();
    final service = LocalNotificationService(buildConfig(), backend: backend);
    await service.initialize();
    final got = <HivorrNotification>[];
    service.onNotificationTapped.listen(got.add);
    backend.capturedOnTap!(exampleTapPayload());
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
    expect(got.first.id, 1);
  });

  test('dispose closes streams without throwing', () async {
    final backend = FakeLocalNotificationBackend();
    final service = LocalNotificationService(buildConfig(), backend: backend);
    await service.initialize();
    service.dispose();
    expect(service.isInitialized, isTrue);
  });
}
