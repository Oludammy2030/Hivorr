import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/channels/notification_channel_manager.dart';
import 'package:hivorr/core/notifications/models/notification_channel.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'notification_test_helpers.dart';

void main() {
  test('createDefaultChannel creates and stores default channel', () async {
    final backend = FakeLocalNotificationBackend();
    final manager = NotificationChannelManager(backend);
    await manager.createDefaultChannel(buildConfig());
    expect(backend.createdChannels, hasLength(1));
    expect(backend.createdChannels.first.id, 'hivorr_default');
    expect(
      backend.createdChannels.first.importance,
      Importance.defaultImportance,
    );
    expect(manager.channels.containsKey('hivorr_default'), isTrue);
  });

  test('createChannel maps importance to AndroidImportance', () async {
    final backend = FakeLocalNotificationBackend();
    final manager = NotificationChannelManager(backend);
    await manager.createChannel(
      NotificationChannel(
        id: 'custom',
        name: 'Custom',
        importance: NotificationPriority.high,
      ),
    );
    expect(manager.channels['custom']!.importance, NotificationPriority.high);
    expect(backend.createdChannels.first.importance, Importance.high);
  });

  test('invalid channel id is rejected', () async {
    final backend = FakeLocalNotificationBackend();
    final manager = NotificationChannelManager(backend);
    await manager.createChannel(
      NotificationChannel(
        id: 'bad id!',
        name: 'x',
        importance: NotificationPriority.normal,
      ),
    );
    expect(backend.createdChannels, isEmpty);
    expect(manager.channels, isEmpty);
  });

  test('deleteChannel removes from registry and forwards', () async {
    final backend = FakeLocalNotificationBackend();
    final manager = NotificationChannelManager(backend);
    await manager.createChannel(
      NotificationChannel(
        id: 'c1',
        name: 'C1',
        importance: NotificationPriority.normal,
      ),
    );
    await manager.deleteChannel('c1');
    expect(manager.channels.containsKey('c1'), isFalse);
    expect(backend.deletedChannels, contains('c1'));
  });
}
