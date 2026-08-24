import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status.dart';
import 'package:hivorr/core/network/network_status_provider.dart';
import 'package:hivorr/core/network/network_type.dart';

void main() {
  NetworkStatus wifiStatus() => NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );

  NetworkStatus mobileStatus() => NetworkStatus(
        isConnected: true,
        networkType: NetworkType.mobile,
        timestamp: DateTime.now(),
      );

  NetworkStatus offlineStatus() => NetworkStatus(
        isConnected: false,
        networkType: NetworkType.none,
        timestamp: DateTime.now(),
      );

  group('NetworkStatusProvider', () {
    test('initial status reflects monitor initial status', () {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.status.isConnected, isTrue);
      expect(provider.isConnected, isTrue);
      expect(provider.networkType, NetworkType.wifi);
    });

    test('status change updates provider', () async {
      final monitor = FakeNetworkMonitor(initial: offlineStatus());
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      final changedCount = <int>[];
      provider.addListener(() => changedCount.add(1));

      await Future<void>.delayed(Duration.zero);
      changedCount.clear();

      monitor.setStatus(wifiStatus());
      await Future<void>.delayed(Duration.zero);

      expect(provider.isConnected, isTrue);
      expect(provider.networkType, NetworkType.wifi);
      expect(changedCount, hasLength(1));
    });

    test('isOnMeteredConnection is true for mobile', () async {
      final monitor = FakeNetworkMonitor(initial: mobileStatus());
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.isOnMeteredConnection, isTrue);
    });

    test('isOnMeteredConnection is false for wifi', () async {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.isOnMeteredConnection, isFalse);
    });

    test('isOnMeteredConnection is false for ethernet', () async {
      final monitor = FakeNetworkMonitor(
        initial: NetworkStatus(
          isConnected: true,
          networkType: NetworkType.ethernet,
          timestamp: DateTime.now(),
        ),
      );
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.isOnMeteredConnection, isFalse);
    });

    test('isOnMeteredConnection is false for vpn', () async {
      final monitor = FakeNetworkMonitor(
        initial: NetworkStatus(
          isConnected: true,
          networkType: NetworkType.vpn,
          timestamp: DateTime.now(),
        ),
      );
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.isOnMeteredConnection, isFalse);
    });

    test('isOnMeteredConnection is false for none', () async {
      final monitor = FakeNetworkMonitor(initial: offlineStatus());
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.isOnMeteredConnection, isFalse);
    });

    test('isOnMeteredConnection is true for bluetooth', () async {
      final monitor = FakeNetworkMonitor(
        initial: NetworkStatus(
          isConnected: true,
          networkType: NetworkType.bluetooth,
          timestamp: DateTime.now(),
        ),
      );
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      expect(provider.isOnMeteredConnection, isTrue);
    });

    test('deduplication: no notify on same status', () async {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      final provider = NetworkStatusProvider(monitor);
      addTearDown(provider.dispose);

      final changedCount = <int>[];
      provider.addListener(() => changedCount.add(1));

      await Future<void>.delayed(Duration.zero);
      changedCount.clear();

      final wifi = wifiStatus();
      monitor.setStatus(wifi);
      await Future<void>.delayed(Duration.zero);

      expect(changedCount, isEmpty);
    });

    test('dispose cancels subscription', () async {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      final provider = NetworkStatusProvider(monitor);

      provider.dispose();
      monitor.dispose();

      expect(() => provider.addListener(() {}), throwsFlutterError);
    });
  });
}
