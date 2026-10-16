import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/channels/lifecycle_channels.dart';
import 'package:hivorr/core/notifications/channels/notification_channel_manager.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'notification_test_helpers.dart';

void main() {
  test('lifecycle channels register six categories with valid ids', () async {
    final backend = FakeLocalNotificationBackend();
    final manager = NotificationChannelManager(backend);
    await LifecycleChannels.registerAll(manager);
    expect(backend.createdChannels, hasLength(6));
    expect(manager.channels.keys, containsAll(<String>[
      'hivorr_contracts',
      'hivorr_escrow',
      'hivorr_messages',
      'hivorr_schedule',
      'hivorr_reviews',
      'hivorr_disputes',
    ]));
  });

  test('messages and escrow are high importance, rest normal', () {
    expect(LifecycleChannels.messages.importance, NotificationPriority.high);
    expect(LifecycleChannels.escrow.importance, NotificationPriority.high);
    expect(LifecycleChannels.contracts.importance, NotificationPriority.normal);
    expect(LifecycleChannels.schedule.importance, NotificationPriority.normal);
    expect(LifecycleChannels.reviews.importance, NotificationPriority.normal);
    expect(LifecycleChannels.disputes.importance, NotificationPriority.normal);
  });
}
