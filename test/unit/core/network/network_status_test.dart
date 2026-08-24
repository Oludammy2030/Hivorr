import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/network/network_status.dart';
import 'package:hivorr/core/network/network_type.dart';

void main() {
  group('NetworkStatus.fromResults', () {
    test('connected wifi', () {
      final status = NetworkStatus.fromResults([ConnectivityResult.wifi]);
      expect(status.isConnected, isTrue);
      expect(status.networkType, NetworkType.wifi);
    });

    test('connected mobile', () {
      final status = NetworkStatus.fromResults([ConnectivityResult.mobile]);
      expect(status.isConnected, isTrue);
      expect(status.networkType, NetworkType.mobile);
    });

    test('disconnected none', () {
      final status = NetworkStatus.fromResults([ConnectivityResult.none]);
      expect(status.isConnected, isFalse);
      expect(status.networkType, NetworkType.none);
    });

    test('multiple interfaces selects primary', () {
      final status = NetworkStatus.fromResults([
        ConnectivityResult.vpn,
        ConnectivityResult.wifi,
      ]);
      expect(status.isConnected, isTrue);
      expect(status.networkType, NetworkType.vpn);
    });

    test('empty list is disconnected', () {
      final status = NetworkStatus.fromResults(<ConnectivityResult>[]);
      expect(status.isConnected, isFalse);
      expect(status.networkType, NetworkType.none);
    });

    test('all-none is disconnected', () {
      final status = NetworkStatus.fromResults([
        ConnectivityResult.none,
        ConnectivityResult.none,
      ]);
      expect(status.isConnected, isFalse);
      expect(status.networkType, NetworkType.none);
    });

    test('timestamp is set to recent time', () {
      final before = DateTime.now();
      final status = NetworkStatus.fromResults([ConnectivityResult.wifi]);
      final after = DateTime.now();

      // Timestamp should be between `before` and `after` (allowing for
      // clock resolution — verify it's recent, not exact ordering).
      expect(
        status.timestamp.isAfter(before.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(
        status.timestamp.isBefore(after.add(Duration(seconds: 1))),
        isTrue,
      );
    });
  });

  group('NetworkStatus.disconnected', () {
    test('is disconnected with none type', () {
      final status = NetworkStatus.disconnected();
      expect(status.isConnected, isFalse);
      expect(status.networkType, NetworkType.none);
    });
  });

  group('NetworkStatus equality', () {
    test('same values are equal', () {
      final now = DateTime.now();
      final a = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: now,
      );
      final b = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: now.add(Duration(seconds: 5)),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different isConnected are not equal', () {
      final a = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );
      final b = NetworkStatus(
        isConnected: false,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );
      expect(a, isNot(equals(b)));
    });

    test('different networkType are not equal', () {
      final a = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );
      final b = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.mobile,
        timestamp: DateTime.now(),
      );
      expect(a, isNot(equals(b)));
    });

    test('identical instances are equal', () {
      final a = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );
      expect(a, equals(a));
    });
  });

  group('NetworkStatus.toString', () {
    test('does not include timestamp or device identifiers', () {
      final status = NetworkStatus(
        isConnected: true,
        networkType: NetworkType.wifi,
        timestamp: DateTime.now(),
      );
      final str = status.toString();
      expect(str, contains('isConnected: true'));
      expect(str, contains('networkType: NetworkType.wifi'));
      expect(str, isNot(contains('timestamp')));
      expect(str, isNot(contains('SSID')));
      expect(str, isNot(contains('BSSID')));
      expect(str, isNot(contains('192.')));
    });
  });
}
