import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/navigation/notification_tap_dispatcher.dart';

HivorrNotification _tap(String? route) => HivorrNotification(
  id: 1,
  title: 't',
  body: 'b',
  channelId: 'hivorr_contracts',
  priority: NotificationPriority.normal,
  actionRoute: route,
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
);

void main() {
  test('allowlist accepts contract, message, appointment, dispute, earnings routes', () {
    const dispatcher = NotificationTapDispatcher();
    expect(
      dispatcher.resolveTarget(_tap('/contracts/abc')),
      '/contracts/abc',
    );
    expect(
      dispatcher.resolveTarget(_tap('/dashboard/messages/abc')),
      '/dashboard/messages/abc',
    );
    expect(
      dispatcher.resolveTarget(_tap('/appointments/abc')),
      '/appointments/abc',
    );
    expect(
      dispatcher.resolveTarget(_tap('/support/disputes/abc')),
      '/support/disputes/abc',
    );
    expect(
      dispatcher.resolveTarget(_tap('/finance/earnings')),
      '/finance/earnings',
    );
  });

  test('disallowed, empty, and null routes are dropped', () {
    const dispatcher = NotificationTapDispatcher();
    expect(dispatcher.resolveTarget(_tap('https://evil.example/x')), isNull);
    expect(dispatcher.resolveTarget(_tap('')), isNull);
    expect(dispatcher.resolveTarget(_tap(null)), isNull);
  });
}
