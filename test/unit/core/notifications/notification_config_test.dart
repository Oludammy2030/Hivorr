import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'notification_test_helpers.dart';

void main() {
  test('fromSource parses all provided values', () {
    final config = buildConfig({
      'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_ID': 'my_channel',
      'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_NAME': 'My Channel',
      'HIVORR_NOTIFICATION_DEFAULT_CHANNEL_DESC': 'desc',
      'HIVORR_NOTIFICATION_ENABLE_PUSH': 'true',
      'HIVORR_NOTIFICATION_ENABLE_LOCAL': 'false',
      'HIVORR_NOTIFICATION_PUSH_CHANNEL_NAME': 'my_events',
      'HIVORR_NOTIFICATION_ICON_RESOURCE': '@mipmap/ic_launcher',
    });
    expect(config.defaultChannelId, 'my_channel');
    expect(config.defaultChannelName, 'My Channel');
    expect(config.defaultChannelDescription, 'desc');
    expect(config.enablePushNotifications, isTrue);
    expect(config.enableLocalNotifications, isFalse);
    expect(config.pushChannelName, 'my_events');
    expect(config.notificationIconResource, '@mipmap/ic_launcher');
  });

  test('fromSource applies documented defaults', () {
    final config = buildConfig();
    expect(config.defaultChannelId, 'hivorr_default');
    expect(config.defaultChannelName, 'Hivorr Notifications');
    expect(config.defaultChannelDescription, 'General notifications from Hivorr');
    expect(config.enablePushNotifications, isFalse);
    expect(config.enableLocalNotifications, isTrue);
    expect(config.pushChannelName, 'notification_events');
    expect(config.notificationIconResource, '@mipmap/ic_launcher');
  });

  test('malformed bool throws EnvironmentConfigException', () {
    expect(
      () => buildConfig({'HIVORR_NOTIFICATION_ENABLE_PUSH': 'yes'}),
      throwsA(isA<EnvironmentConfigException>()),
    );
  });
}
