import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';

void main() {
  test('enablePushNotifications defaults to false', () {
    final flags = FeatureFlags.fromSource(MapEnvironmentValueSource({}));
    expect(flags.enablePushNotifications, isFalse);
  });

  test('enablePushNotifications true', () {
    final flags = FeatureFlags.fromSource(
      MapEnvironmentValueSource({
        'HIVORR_FEATURE_ENABLE_PUSH_NOTIFICATIONS': 'true',
      }),
    );
    expect(flags.enablePushNotifications, isTrue);
  });

  test('enablePushNotifications false', () {
    final flags = FeatureFlags.fromSource(
      MapEnvironmentValueSource({
        'HIVORR_FEATURE_ENABLE_PUSH_NOTIFICATIONS': 'false',
      }),
    );
    expect(flags.enablePushNotifications, isFalse);
  });

  test('malformed value throws', () {
    expect(
      () => FeatureFlags.fromSource(
        MapEnvironmentValueSource({
          'HIVORR_FEATURE_ENABLE_PUSH_NOTIFICATIONS': 'maybe',
        }),
      ),
      throwsA(isA<EnvironmentConfigException>()),
    );
  });
}
