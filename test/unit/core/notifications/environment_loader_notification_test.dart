import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_loader.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

void main() {
  test('step 11 wires NotificationConfig with documented defaults', () {
    final config = EnvironmentLoader.load(
      source: MapEnvironmentValueSource({
        'HIVORR_ENV': 'development',
        'HIVORR_SUPABASE_URL': 'https://example.supabase.co',
        'HIVORR_SUPABASE_ANON_KEY': 'public-anon-key',
        'HIVORR_CONFIG_SCHEMA_VERSION': '1',
      }),
    );
    expect(config.notificationConfig, isNotNull);
    expect(config.notificationConfig.defaultChannelId, 'hivorr_default');
    expect(config.notificationConfig.enablePushNotifications, isFalse);
    expect(config.notificationConfig.enableLocalNotifications, isTrue);
  });

  test('step 11 honors push enabled value', () {
    final config = EnvironmentLoader.load(
      source: MapEnvironmentValueSource({
        'HIVORR_ENV': 'development',
        'HIVORR_SUPABASE_URL': 'https://example.supabase.co',
        'HIVORR_SUPABASE_ANON_KEY': 'public-anon-key',
        'HIVORR_CONFIG_SCHEMA_VERSION': '1',
        'HIVORR_NOTIFICATION_ENABLE_PUSH': 'true',
      }),
    );
    expect(config.notificationConfig.enablePushNotifications, isTrue);
  });
}
