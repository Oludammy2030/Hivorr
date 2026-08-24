import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/network/network_config.dart';
import 'package:hivorr/core/network/network_type.dart';
import 'package:hivorr/core/network/payload_optimizer.dart';

void main() {
  const config = NetworkConfig(
    debounceIntervalMs: 0,
    enablePayloadOptimization: true,
    mobileImageQuality: 'low',
    wifiImageQuality: 'medium',
    mobilePageSize: 15,
    wifiPageSize: 30,
    maxUploadSizeMbMobile: 5.0,
    maxUploadSizeMbWifi: 25.0,
  );

  final optimizer = PayloadOptimizer(config);

  group('recommendedImageQuality', () {
    test('mobile → low', () {
      expect(optimizer.recommendedImageQuality(NetworkType.mobile),
          ImageQuality.low);
    });

    test('bluetooth → low', () {
      expect(optimizer.recommendedImageQuality(NetworkType.bluetooth),
          ImageQuality.low);
    });

    test('wifi → medium', () {
      expect(optimizer.recommendedImageQuality(NetworkType.wifi),
          ImageQuality.medium);
    });

    test('ethernet → high', () {
      expect(optimizer.recommendedImageQuality(NetworkType.ethernet),
          ImageQuality.high);
    });

    test('vpn → high', () {
      expect(optimizer.recommendedImageQuality(NetworkType.vpn),
          ImageQuality.high);
    });

    test('none → low (conservative)', () {
      expect(optimizer.recommendedImageQuality(NetworkType.none),
          ImageQuality.low);
    });

    test('other → mobileImageQuality default', () {
      expect(optimizer.recommendedImageQuality(NetworkType.other),
          ImageQuality.low);
    });
  });

  group('recommendedPageSize', () {
    test('mobile → 15', () {
      expect(optimizer.recommendedPageSize(NetworkType.mobile), 15);
    });

    test('bluetooth → 15', () {
      expect(optimizer.recommendedPageSize(NetworkType.bluetooth), 15);
    });

    test('wifi → 30', () {
      expect(optimizer.recommendedPageSize(NetworkType.wifi), 30);
    });

    test('ethernet → 30', () {
      expect(optimizer.recommendedPageSize(NetworkType.ethernet), 30);
    });

    test('vpn → 30', () {
      expect(optimizer.recommendedPageSize(NetworkType.vpn), 30);
    });

    test('none → 15 (conservative)', () {
      expect(optimizer.recommendedPageSize(NetworkType.none), 15);
    });

    test('other → 15', () {
      expect(optimizer.recommendedPageSize(NetworkType.other), 15);
    });
  });

  group('shouldCompressPayload', () {
    test('mobile → true', () {
      expect(optimizer.shouldCompressPayload(NetworkType.mobile), isTrue);
    });

    test('bluetooth → true', () {
      expect(optimizer.shouldCompressPayload(NetworkType.bluetooth), isTrue);
    });

    test('wifi → false', () {
      expect(optimizer.shouldCompressPayload(NetworkType.wifi), isFalse);
    });

    test('ethernet → false', () {
      expect(optimizer.shouldCompressPayload(NetworkType.ethernet), isFalse);
    });

    test('vpn → false', () {
      expect(optimizer.shouldCompressPayload(NetworkType.vpn), isFalse);
    });

    test('none → false', () {
      expect(optimizer.shouldCompressPayload(NetworkType.none), isFalse);
    });

    test('other → false', () {
      expect(optimizer.shouldCompressPayload(NetworkType.other), isFalse);
    });
  });

  group('isMeteredConnection', () {
    test('mobile → true', () {
      expect(optimizer.isMeteredConnection(NetworkType.mobile), isTrue);
    });

    test('bluetooth → true', () {
      expect(optimizer.isMeteredConnection(NetworkType.bluetooth), isTrue);
    });

    test('wifi → false', () {
      expect(optimizer.isMeteredConnection(NetworkType.wifi), isFalse);
    });

    test('ethernet → false', () {
      expect(optimizer.isMeteredConnection(NetworkType.ethernet), isFalse);
    });

    test('vpn → false', () {
      expect(optimizer.isMeteredConnection(NetworkType.vpn), isFalse);
    });

    test('none → false', () {
      expect(optimizer.isMeteredConnection(NetworkType.none), isFalse);
    });

    test('other → false', () {
      expect(optimizer.isMeteredConnection(NetworkType.other), isFalse);
    });
  });

  group('recommendedMaxUploadSizeMb', () {
    test('mobile → 5.0', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.mobile), 5.0);
    });

    test('bluetooth → 5.0', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.bluetooth), 5.0);
    });

    test('wifi → 25.0', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.wifi), 25.0);
    });

    test('ethernet → 25.0', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.ethernet), 25.0);
    });

    test('vpn → 25.0', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.vpn), 25.0);
    });

    test('none → 5.0 (conservative)', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.none), 5.0);
    });

    test('other → 5.0', () {
      expect(optimizer.recommendedMaxUploadSizeMb(NetworkType.other), 5.0);
    });
  });

  group('config-driven recommendations', () {
    test('custom wifi image quality is respected', () {
      const customConfig = NetworkConfig(
        debounceIntervalMs: 0,
        enablePayloadOptimization: true,
        mobileImageQuality: 'low',
        wifiImageQuality: 'high',
        mobilePageSize: 15,
        wifiPageSize: 30,
        maxUploadSizeMbMobile: 5.0,
        maxUploadSizeMbWifi: 25.0,
      );

      final customOptimizer = PayloadOptimizer(customConfig);

      expect(customOptimizer.recommendedImageQuality(NetworkType.wifi),
          ImageQuality.high);
    });

    test('custom page sizes are respected', () {
      const customConfig = NetworkConfig(
        debounceIntervalMs: 0,
        enablePayloadOptimization: true,
        mobileImageQuality: 'low',
        wifiImageQuality: 'medium',
        mobilePageSize: 10,
        wifiPageSize: 50,
        maxUploadSizeMbMobile: 5.0,
        maxUploadSizeMbWifi: 25.0,
      );

      final customOptimizer = PayloadOptimizer(customConfig);

      expect(customOptimizer.recommendedPageSize(NetworkType.mobile), 10);
      expect(customOptimizer.recommendedPageSize(NetworkType.wifi), 50);
    });

    test('custom upload sizes are respected', () {
      const customConfig = NetworkConfig(
        debounceIntervalMs: 0,
        enablePayloadOptimization: true,
        mobileImageQuality: 'low',
        wifiImageQuality: 'medium',
        mobilePageSize: 15,
        wifiPageSize: 30,
        maxUploadSizeMbMobile: 10.0,
        maxUploadSizeMbWifi: 100.0,
      );

      final customOptimizer = PayloadOptimizer(customConfig);

      expect(customOptimizer.recommendedMaxUploadSizeMb(NetworkType.mobile),
          10.0);
      expect(customOptimizer.recommendedMaxUploadSizeMb(NetworkType.wifi),
          100.0);
    });
  });
}
