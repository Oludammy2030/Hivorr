import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_prompt.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:provider/provider.dart';

import '../../support/fakes/fake_notifications.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  testWidgets('denied permission shows HivorrErrorState with enable action', (
    WidgetTester tester,
  ) async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.denied,
    );
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
    );
    await provider.initialize();

    await pumpApp(
      tester,
      const NotificationPermissionPrompt(),
      providers: <ChangeNotifierProvider<NotificationProvider>>[
        ChangeNotifierProvider<NotificationProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications are off'), findsOneWidget);
    expect(find.text('Enable notifications'), findsOneWidget);
  });

  testWidgets('granted permission renders nothing', (WidgetTester tester) async {
    final service = FakeNotificationService();
    final platform = FakeNotificationPermissionPlatform(
      nextStatus: NotificationPermissionStatus.granted,
    );
    final provider = NotificationProvider(
      service,
      NotificationPermissionManager(platform: platform),
    );
    await provider.initialize();

    await pumpApp(
      tester,
      const NotificationPermissionPrompt(),
      providers: <ChangeNotifierProvider<NotificationProvider>>[
        ChangeNotifierProvider<NotificationProvider>.value(value: provider),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications are off'), findsNothing);
  });
}
