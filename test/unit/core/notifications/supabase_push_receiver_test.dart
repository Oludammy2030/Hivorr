import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/push/supabase_push_receiver.dart';
import 'notification_test_helpers.dart';

void main() {
  test('subscribe delegates with entity id and is idempotent', () async {
    final gateway = FakePushRealtimeGateway();
    final receiver = SupabasePushReceiver(buildConfig(), gateway);
    await receiver.subscribe('entity-1');
    expect(gateway.subscribedEntityId, 'entity-1');
    expect(gateway.subscribeCallCount, 1);
    expect(receiver.isSubscribed, isTrue);

    await receiver.subscribe('entity-1');
    expect(gateway.subscribeCallCount, 1);
    expect(gateway.subscribedChannel, 'notification_events');
  });

  test('unsubscribe delegates and clears state', () async {
    final gateway = FakePushRealtimeGateway();
    final receiver = SupabasePushReceiver(buildConfig(), gateway);
    await receiver.subscribe('e');
    await receiver.unsubscribe();
    expect(receiver.isSubscribed, isFalse);
    expect(gateway.unsubscribed, isTrue);
  });

  test('onMessage emits mapped notification', () async {
    final gateway = FakePushRealtimeGateway();
    final receiver = SupabasePushReceiver(buildConfig(), gateway);
    await receiver.subscribe('e');
    final got = <HivorrNotification>[];
    receiver.onMessage.listen(got.add);
    gateway.emitEvent(<String, dynamic>{
      'id': 42,
      'title': 'Hi',
      'body': 'There',
      'channel_id': 'hivorr_messages',
      'priority': 'high',
      'action_route': '/x',
      'payload': <String, dynamic>{'k': 'v'},
    });
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
    expect(got.first.id, 42);
    expect(got.first.title, 'Hi');
    expect(got.first.priority, NotificationPriority.high);
    expect(got.first.actionRoute, '/x');
  });

  test('partial/odd payload handled gracefully', () async {
    final gateway = FakePushRealtimeGateway();
    final receiver = SupabasePushReceiver(buildConfig(), gateway);
    await receiver.subscribe('e');
    final got = <HivorrNotification>[];
    receiver.onMessage.listen(got.add);
    gateway.emitEvent(<String, dynamic>{'id': 5});
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
    expect(got.first.id, 5);
  });
}
