import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';

void main() {
  test('values map to expected numeric weights', () {
    expect(NotificationPriority.low.value, 0);
    expect(NotificationPriority.normal.value, 1);
    expect(NotificationPriority.high.value, 2);
    expect(NotificationPriority.urgent.value, 3);
  });

  test('enum exposes all four levels', () {
    expect(NotificationPriority.values, hasLength(4));
    expect(
      NotificationPriority.values,
      containsAll(<NotificationPriority>[
        NotificationPriority.low,
        NotificationPriority.normal,
        NotificationPriority.high,
        NotificationPriority.urgent,
      ]),
    );
  });
}
