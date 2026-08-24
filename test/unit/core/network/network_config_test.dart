import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/network/network_config.dart';

void main() {
  group('NetworkConfig.fromSource — defaults', () {
    test('all defaults applied when no values provided', () {
      const source = MapEnvironmentValueSource({});

      final config = NetworkConfig.fromSource(source);

      expect(config.debounceIntervalMs,
          AppConstants.defaultNetworkDebounceMs);
      expect(config.enablePayloadOptimization, isFalse);
      expect(config.mobileImageQuality,
          AppConstants.defaultNetworkMobileImageQuality);
      expect(config.wifiImageQuality,
          AppConstants.defaultNetworkWifiImageQuality);
      expect(config.mobilePageSize,
          AppConstants.defaultNetworkMobilePageSize);
      expect(config.wifiPageSize, AppConstants.defaultNetworkWifiPageSize);
      expect(config.maxUploadSizeMbMobile,
          AppConstants.defaultNetworkMaxUploadMbMobile);
      expect(config.maxUploadSizeMbWifi,
          AppConstants.defaultNetworkMaxUploadMbWifi);
    });
  });

  group('NetworkConfig.fromSource — all values provided', () {
    test('parses all values correctly', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkDebounceMs: '500',
        AppConstants.featureEnablePayloadOptimization: 'true',
        AppConstants.envNetworkMobileImageQuality: 'high',
        AppConstants.envNetworkWifiImageQuality: 'high',
        AppConstants.envNetworkMobilePageSize: '20',
        AppConstants.envNetworkWifiPageSize: '50',
        AppConstants.envNetworkMaxUploadMbMobile: '10.5',
        AppConstants.envNetworkMaxUploadMbWifi: '100.0',
      });

      final config = NetworkConfig.fromSource(source);

      expect(config.debounceIntervalMs, 500);
      expect(config.enablePayloadOptimization, isTrue);
      expect(config.mobileImageQuality, 'high');
      expect(config.wifiImageQuality, 'high');
      expect(config.mobilePageSize, 20);
      expect(config.wifiPageSize, 50);
      expect(config.maxUploadSizeMbMobile, 10.5);
      expect(config.maxUploadSizeMbWifi, 100.0);
    });

    test('enablePayloadOptimization false', () {
      const source = MapEnvironmentValueSource({
        AppConstants.featureEnablePayloadOptimization: 'false',
      });

      final config = NetworkConfig.fromSource(source);

      expect(config.enablePayloadOptimization, isFalse);
    });

    test('enablePayloadOptimization malformed throws', () {
      const source = MapEnvironmentValueSource({
        AppConstants.featureEnablePayloadOptimization: 'yes',
      });

      expect(
        () => NetworkConfig.fromSource(source),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('malformed integer throws', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkDebounceMs: 'abc',
      });

      expect(
        () => NetworkConfig.fromSource(source),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('negative integer throws', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkDebounceMs: '-1',
      });

      expect(
        () => NetworkConfig.fromSource(source),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('malformed double throws', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkMaxUploadMbMobile: 'xyz',
      });

      expect(
        () => NetworkConfig.fromSource(source),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('negative double throws', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkMaxUploadMbWifi: '-5.0',
      });

      expect(
        () => NetworkConfig.fromSource(source),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('image quality enums resolve correctly', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkMobileImageQuality: 'low',
        AppConstants.envNetworkWifiImageQuality: 'high',
      });

      final config = NetworkConfig.fromSource(source);

      expect(config.mobileImageQualityEnum, ImageQuality.low);
      expect(config.wifiImageQualityEnum, ImageQuality.high);
    });

    test('invalid image quality string defaults to medium', () {
      const source = MapEnvironmentValueSource({
        AppConstants.envNetworkMobileImageQuality: 'ultra',
      });

      final config = NetworkConfig.fromSource(source);

      expect(config.mobileImageQualityEnum, ImageQuality.medium);
    });
  });

  group('NetworkConfig.toString', () {
    test('includes all fields', () {
      const config = NetworkConfig(
        debounceIntervalMs: 300,
        enablePayloadOptimization: true,
        mobileImageQuality: 'low',
        wifiImageQuality: 'medium',
        mobilePageSize: 15,
        wifiPageSize: 30,
        maxUploadSizeMbMobile: 5.0,
        maxUploadSizeMbWifi: 25.0,
      );

      final str = config.toString();

      expect(str, contains('debounceIntervalMs: 300'));
      expect(str, contains('enablePayloadOptimization: true'));
      expect(str, contains('mobileImageQuality: low'));
      expect(str, contains('wifiImageQuality: medium'));
      expect(str, contains('mobilePageSize: 15'));
      expect(str, contains('wifiPageSize: 30'));
      expect(str, contains('maxUploadSizeMbMobile: 5.0'));
      expect(str, contains('maxUploadSizeMbWifi: 25.0'));
    });
  });
}
