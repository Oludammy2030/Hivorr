import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/notification_channel.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';

void main() {
  test('constructor exposes declared fields', () {
    final channel = NotificationChannel(
      id: 'c',
      name: 'C',
      description: 'd',
      importance: NotificationPriority.high,
      enableLed: true,
      ledColor: 0xFF00FF00,
    );
    expect(channel.id, 'c');
    expect(channel.name, 'C');
    expect(channel.description, 'd');
    expect(channel.importance, NotificationPriority.high);
    expect(channel.enableLed, isTrue);
    expect(channel.ledColor, 0xFF00FF00);
  });

  test('copyWith replaces only provided fields', () {
    final channel = NotificationChannel(
      id: 'c',
      name: 'C',
      importance: NotificationPriority.normal,
    );
    final copy = channel.copyWith(importance: NotificationPriority.urgent);
    expect(copy.id, 'c');
    expect(copy.name, 'C');
    expect(copy.importance, NotificationPriority.urgent);
  });
}
