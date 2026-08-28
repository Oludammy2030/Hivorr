import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'notification_test_helpers.dart';

void main() {
  test('checkStatus returns platform status', () async {
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
    );
    final manager = NotificationPermissionManager(platform: platform);
    expect(await manager.checkStatus(), NotificationPermissionStatus.granted);
  });

  test(
    'requestPermission delegates and updates canRequestPermission',
    () async {
      final platform = FakeNotificationPermissionPlatform(
        nextStatus: NotificationPermissionStatus.denied,
        canRequest: true,
      );
      final manager = NotificationPermissionManager(platform: platform);
      expect(
        await manager.requestPermission(),
        NotificationPermissionStatus.denied,
      );
      expect(manager.canRequestPermission, isTrue);
    },
  );

  test('canRequestPermission false when granted', () async {
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
      canRequest: true,
    );
    final manager = NotificationPermissionManager(platform: platform);
    await manager.requestPermission();
    expect(manager.canRequestPermission, isFalse);
  });

  test('canRequestPermission false when permanently denied', () {
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.permanentlyDenied,
      canRequest: false,
    );
    final manager = NotificationPermissionManager(platform: platform);
    expect(manager.canRequestPermission, isFalse);
  });
}
