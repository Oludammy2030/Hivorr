import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';

void main() {
  test('enum exposes all states', () {
    expect(
      NotificationPermissionStatus.values,
      containsAll(<NotificationPermissionStatus>[
        NotificationPermissionStatus.notDetermined,
        NotificationPermissionStatus.granted,
        NotificationPermissionStatus.denied,
        NotificationPermissionStatus.permanentlyDenied,
        NotificationPermissionStatus.provisional,
      ]),
    );
  });
}
