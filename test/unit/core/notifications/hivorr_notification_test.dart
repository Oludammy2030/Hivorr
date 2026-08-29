import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';

const _timestamp = '2024-01-02T03:04:05.000Z';

void main() {
  test('toJson / fromJson round-trip preserves fields', () {
    final original = HivorrNotification(
      id: 5,
      title: 'Hello',
      body: 'World',
      channelId: 'hivorr_default',
      priority: NotificationPriority.high,
      timestamp: DateTime.parse(_timestamp),
      actionRoute: '/chat/1',
      payload: <String, dynamic>{'k': 'v'},
    );
    final decoded = HivorrNotification.fromJson(original.toJson());
    expect(decoded.id, original.id);
    expect(decoded.title, original.title);
    expect(decoded.body, original.body);
    expect(decoded.channelId, original.channelId);
    expect(decoded.priority, original.priority);
    expect(decoded.timestamp, original.timestamp);
    expect(decoded.actionRoute, original.actionRoute);
    expect(decoded.payload, original.payload);
  });

  test('fromJson tolerates missing optional fields', () {
    final decoded = HivorrNotification.fromJson(<String, dynamic>{
      'id': 1,
      'title': 'T',
      'body': 'B',
      'channelId': 'c',
      'priority': 'normal',
    });
    expect(decoded.actionRoute, isNull);
    expect(decoded.payload, isNull);
    expect(decoded.timestamp, isA<DateTime>());
  });

  test('fromJson defaults unknown priority to normal', () {
    final decoded = HivorrNotification.fromJson(<String, dynamic>{
      'id': 1,
      'title': 'T',
      'body': 'B',
      'channelId': 'c',
      'priority': 'bogus',
    });
    expect(decoded.priority, NotificationPriority.normal);
  });
}
