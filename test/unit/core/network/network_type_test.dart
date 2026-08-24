import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/network/network_type.dart';

void main() {
  group('mapConnectivityResult', () {
    test('maps wifi', () {
      expect(mapConnectivityResult(ConnectivityResult.wifi), NetworkType.wifi);
    });

    test('maps mobile', () {
      expect(
        mapConnectivityResult(ConnectivityResult.mobile),
        NetworkType.mobile,
      );
    });

    test('maps ethernet', () {
      expect(
        mapConnectivityResult(ConnectivityResult.ethernet),
        NetworkType.ethernet,
      );
    });

    test('maps vpn', () {
      expect(mapConnectivityResult(ConnectivityResult.vpn), NetworkType.vpn);
    });

    test('maps bluetooth', () {
      expect(
        mapConnectivityResult(ConnectivityResult.bluetooth),
        NetworkType.bluetooth,
      );
    });

    test('maps none', () {
      expect(mapConnectivityResult(ConnectivityResult.none), NetworkType.none);
    });

    test('maps other', () {
      expect(
        mapConnectivityResult(ConnectivityResult.other),
        NetworkType.other,
      );
    });

    test('maps satellite to other', () {
      expect(
        mapConnectivityResult(ConnectivityResult.satellite),
        NetworkType.other,
      );
    });
  });

  group('selectPrimaryNetworkType', () {
    test('returns none for empty list', () {
      expect(selectPrimaryNetworkType(<ConnectivityResult>[]), NetworkType.none);
    });

    test('returns none for all-none results', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.none,
          ConnectivityResult.none,
        ]),
        NetworkType.none,
      );
    });

    test('selects vpn over wifi', () {
      expect(
        selectPrimaryNetworkType([ConnectivityResult.vpn, ConnectivityResult.wifi]),
        NetworkType.vpn,
      );
    });

    test('selects ethernet over mobile', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.ethernet,
          ConnectivityResult.mobile,
        ]),
        NetworkType.ethernet,
      );
    });

    test('selects wifi over mobile', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        NetworkType.wifi,
      );
    });

    test('selects mobile over bluetooth', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.mobile,
          ConnectivityResult.bluetooth,
        ]),
        NetworkType.mobile,
      );
    });

    test('selects bluetooth over other', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.bluetooth,
          ConnectivityResult.other,
        ]),
        NetworkType.bluetooth,
      );
    });

    test('selects single wifi', () {
      expect(
        selectPrimaryNetworkType([ConnectivityResult.wifi]),
        NetworkType.wifi,
      );
    });

    test('selects vpn when present alongside multiple others', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
          ConnectivityResult.vpn,
          ConnectivityResult.bluetooth,
        ]),
        NetworkType.vpn,
      );
    });

    test('selects ethernet when vpn is absent', () {
      expect(
        selectPrimaryNetworkType([
          ConnectivityResult.ethernet,
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        NetworkType.ethernet,
      );
    });
  });
}
