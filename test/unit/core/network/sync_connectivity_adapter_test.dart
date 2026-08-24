import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status.dart';
import 'package:hivorr/core/network/network_type.dart';
import 'package:hivorr/core/network/sync_connectivity_adapter.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';

void main() {
  NetworkStatus onlineWifi() => NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );

  NetworkStatus onlineMobile() => NetworkStatus(
        isConnected: true,
        networkType: NetworkType.mobile,
        timestamp: DateTime.now(),
      );

  NetworkStatus offline() => NetworkStatus(
        isConnected: false,
        networkType: NetworkType.none,
        timestamp: DateTime.now(),
      );

  group('SyncConnectivityAdapter', () {
    test('is a ConnectivityProvider', () {
      final monitor = FakeNetworkMonitor();
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      expect(adapter, isA<ConnectivityProvider>());
    });

    test('onConnectivityChanged maps online status to ConnectivityStatus.online',
        () async {
      final monitor = FakeNetworkMonitor(initial: offline());
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      final statuses = <ConnectivityStatus>[];
      final sub = adapter.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      monitor.setStatus(onlineWifi());
      await Future<void>.delayed(Duration.zero);

      expect(statuses, <ConnectivityStatus>[ConnectivityStatus.online]);
    });

    test(
        'onConnectivityChanged maps offline status to ConnectivityStatus.offline',
        () async {
      final monitor = FakeNetworkMonitor(initial: onlineWifi());
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      final statuses = <ConnectivityStatus>[];
      final sub = adapter.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      monitor.setStatus(offline());
      await Future<void>.delayed(Duration.zero);

      expect(statuses, <ConnectivityStatus>[ConnectivityStatus.offline]);
    });

    test('online with different network type still emits online', () async {
      final monitor = FakeNetworkMonitor(initial: onlineWifi());
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      final statuses = <ConnectivityStatus>[];
      final sub = adapter.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      monitor.setStatus(onlineMobile());
      await Future<void>.delayed(Duration.zero);

      // NetworkStatus changes from wifi to mobile — both are online.
      // The adapter maps to ConnectivityStatus.online.
      expect(statuses, <ConnectivityStatus>[ConnectivityStatus.online]);
    });

    test('isConnected delegates to NetworkMonitor.currentStatus', () async {
      final monitor = FakeNetworkMonitor(initial: onlineWifi());
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      final connected = await adapter.isConnected;

      expect(connected, isTrue);
    });

    test('isConnected returns false when offline', () async {
      final monitor = FakeNetworkMonitor(initial: offline());
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      final connected = await adapter.isConnected;

      expect(connected, isFalse);
    });

    test('dispose is a no-op (monitor lifecycle owned externally)', () {
      final monitor = FakeNetworkMonitor();
      addTearDown(monitor.dispose);

      final adapter = SyncConnectivityAdapter(monitor);

      // Should not throw and should not dispose the monitor.
      adapter.dispose();

      // Monitor should still be functional.
      expect(monitor.lastKnownStatus.isConnected, isFalse);
    });
  });
}
