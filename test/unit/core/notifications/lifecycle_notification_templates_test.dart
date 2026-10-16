import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/templates/lifecycle_notification_templates.dart';

void main() {
  test('shortId redacts to last4 with *** prefix', () {
    expect(LifecycleNotificationTemplates.shortId('abcdefgh'), '***efgh');
    expect(LifecycleNotificationTemplates.shortId('ab'), '***ab');
  });

  test('templates carry no PII and route to canonical paths', () {
    final offered = LifecycleNotificationTemplates.contractOffered(
      '11111111-2222-3333-4444-555555555555',
    );
    expect(offered.title, 'New contract offer');
    expect(offered.body, contains('***5555'));
    expect(offered.body.contains('@'), isFalse);
    expect(
      offered.actionRoute.startsWith('/contracts/'),
      isTrue,
    );
    expect(offered.payload['event'], 'contract_offered');

    final message = LifecycleNotificationTemplates.messageReceived(
      '11111111-2222-3333-4444-555555555555',
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );
    expect(message.priority, NotificationPriority.high);
    expect(
      message.actionRoute.startsWith('/dashboard/messages/'),
      isTrue,
    );
    expect(message.body.contains('@'), isFalse);

    final earnings = LifecycleNotificationTemplates.earningsReleased(
      '11111111-2222-3333-4444-555555555555',
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    );
    expect(earnings.actionRoute, '/finance/earnings');
    expect(earnings.priority, NotificationPriority.high);
  });
}
