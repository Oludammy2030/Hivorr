import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';

void main() {
  group('ManualConnectivityProvider', () {
    test('initial status is online by default', () async {
      final provider = ManualConnectivityProvider();
      addTearDown(provider.dispose);

      expect(await provider.isConnected, isTrue);
    });

    test('initial status can be set to offline', () async {
      final provider = ManualConnectivityProvider(
        initial: ConnectivityStatus.offline,
      );
      addTearDown(provider.dispose);

      expect(await provider.isConnected, isFalse);
    });

    test('setOnline emits online status', () async {
      final provider = ManualConnectivityProvider(
        initial: ConnectivityStatus.offline,
      );
      addTearDown(provider.dispose);

      final statuses = <ConnectivityStatus>[];
      final sub = provider.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      // Allow initial emission.
      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      provider.setOnline();
      await Future<void>.delayed(Duration.zero);

      expect(statuses, <ConnectivityStatus>[ConnectivityStatus.online]);
      expect(await provider.isConnected, isTrue);
    });

    test('setOffline emits offline status', () async {
      final provider = ManualConnectivityProvider();
      addTearDown(provider.dispose);

      final statuses = <ConnectivityStatus>[];
      final sub = provider.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      provider.setOffline();
      await Future<void>.delayed(Duration.zero);

      expect(statuses, <ConnectivityStatus>[ConnectivityStatus.offline]);
      expect(await provider.isConnected, isFalse);
    });

    test('stream emits initial status on listen', () async {
      final provider = ManualConnectivityProvider(
        initial: ConnectivityStatus.online,
      );
      addTearDown(provider.dispose);

      final statuses = <ConnectivityStatus>[];
      final sub = provider.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);

      expect(statuses, <ConnectivityStatus>[ConnectivityStatus.online]);
    });

    test('multiple state changes are emitted in order', () async {
      final provider = ManualConnectivityProvider();
      addTearDown(provider.dispose);

      final statuses = <ConnectivityStatus>[];
      final sub = provider.onConnectivityChanged.listen(statuses.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      statuses.clear();

      provider.setOffline();
      provider.setOnline();
      provider.setOffline();
      await Future<void>.delayed(Duration.zero);

      expect(
        statuses,
        <ConnectivityStatus>[
          ConnectivityStatus.offline,
          ConnectivityStatus.online,
          ConnectivityStatus.offline,
        ],
      );
    });
  });
}
