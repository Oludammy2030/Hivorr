import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status.dart';
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

  group('FakeNetworkMonitor', () {
    test('initial status is disconnected by default', () {
      final monitor = FakeNetworkMonitor();
      addTearDown(monitor.dispose);

      expect(monitor.lastKnownStatus.isConnected, isFalse);
      expect(monitor.lastKnownStatus.networkType, NetworkType.none);
    });

    test('initial status can be provided', () {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      expect(monitor.lastKnownStatus.isConnected, isTrue);
      expect(monitor.lastKnownStatus.networkType, NetworkType.wifi);
    });

    test('stream emits initial status on listen', () async {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      final statuses = <NetworkStatus>[];
      final sub = monitor.onStatusChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);

      expect(statuses, hasLength(1));
      expect(statuses.first.isConnected, isTrue);
      expect(statuses.first.networkType, NetworkType.wifi);
    });

    test('setStatus emits new status', () async {
      final monitor = FakeNetworkMonitor(initial: offlineStatus());
      addTearDown(monitor.dispose);

      final statuses = <NetworkStatus>[];
      final sub = monitor.onStatusChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      monitor.setStatus(wifiStatus());
      await Future<void>.delayed(Duration.zero);

      expect(statuses, hasLength(1));
      expect(statuses.first.isConnected, isTrue);
      expect(statuses.first.networkType, NetworkType.wifi);
    });

    test('deduplication: same status not emitted twice', () async {
      final monitor = FakeNetworkMonitor(initial: offlineStatus());
      addTearDown(monitor.dispose);

      final statuses = <NetworkStatus>[];
      final sub = monitor.onStatusChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      final wifi = wifiStatus();
      monitor.setStatus(wifi);
      monitor.setStatus(wifiStatus());
      await Future<void>.delayed(Duration.zero);

      expect(statuses, hasLength(1));
    });

    test('lastKnownStatus returns most recent without platform call', () {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      monitor.setStatus(mobileStatus());

      expect(monitor.lastKnownStatus.networkType, NetworkType.mobile);
    });

    test('currentStatus returns same as lastKnown', () async {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      addTearDown(monitor.dispose);

      final status = await monitor.currentStatus;

      expect(status.isConnected, isTrue);
      expect(status.networkType, NetworkType.wifi);
    });

    test('multiple state changes are emitted in order', () async {
      final monitor = FakeNetworkMonitor(initial: offlineStatus());
      addTearDown(monitor.dispose);

      final types = <NetworkType>[];
      final sub = monitor.onStatusChanged.listen((s) => types.add(s.networkType));
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      types.clear();

      monitor.setStatus(wifiStatus());
      monitor.setStatus(mobileStatus());
      monitor.setStatus(offlineStatus());
      await Future<void>.delayed(Duration.zero);

      expect(
        types,
        <NetworkType>[NetworkType.wifi, NetworkType.mobile, NetworkType.none],
      );
    });

    test('dispose closes stream', () async {
      final monitor = FakeNetworkMonitor(initial: wifiStatus());
      monitor.dispose();

      final statuses = <NetworkStatus>[];
      final sub = monitor.onStatusChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);

      expect(statuses, isEmpty);
    });
  });
}
