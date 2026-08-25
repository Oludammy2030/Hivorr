import 'package:connectivity_plus/connectivity_plus.dart';

/// The type of network interface currently active on the device.
///
/// Mapped from `connectivity_plus`'s `ConnectivityResult` with priority-based
/// selection when multiple interfaces are active (EP-01-13 §5.3).
enum NetworkType { wifi, mobile, ethernet, vpn, bluetooth, none, other }

/// Maps a single `ConnectivityResult` to a [NetworkType].
NetworkType mapConnectivityResult(ConnectivityResult result) {
  return switch (result) {
    ConnectivityResult.wifi => NetworkType.wifi,
    ConnectivityResult.mobile => NetworkType.mobile,
    ConnectivityResult.ethernet => NetworkType.ethernet,
    ConnectivityResult.vpn => NetworkType.vpn,
    ConnectivityResult.bluetooth => NetworkType.bluetooth,
    ConnectivityResult.none => NetworkType.none,
    ConnectivityResult.satellite => NetworkType.other,
    ConnectivityResult.other => NetworkType.other,
  };
}

/// Priority order for selecting the primary interface when multiple
/// `ConnectivityResult`s are active (EP-01-13 §5.3).
///
/// Higher index = higher priority. `vpn` wins over `ethernet`, which wins
/// over `wifi`, etc. `none` has the lowest priority.
const Map<NetworkType, int> _networkTypePriority = {
  NetworkType.vpn: 6,
  NetworkType.ethernet: 5,
  NetworkType.wifi: 4,
  NetworkType.mobile: 3,
  NetworkType.bluetooth: 2,
  NetworkType.other: 1,
  NetworkType.none: 0,
};

/// Selects the primary [NetworkType] from a list of `ConnectivityResult`s
/// using priority-based selection (EP-01-13 §5.3).
///
/// When multiple interfaces are active, the interface most likely carrying
/// traffic is selected: `vpn` > `ethernet` > `wifi` > `mobile` >
/// `bluetooth` > `other` > `none`.
///
/// An empty list or a list where all results are `none` yields
/// [NetworkType.none].
NetworkType selectPrimaryNetworkType(List<ConnectivityResult> results) {
  if (results.isEmpty) {
    return NetworkType.none;
  }

  NetworkType best = NetworkType.none;
  int bestPriority = _networkTypePriority[NetworkType.none]!;

  for (final result in results) {
    final type = mapConnectivityResult(result);
    final priority = _networkTypePriority[type] ?? 0;
    if (priority > bestPriority) {
      bestPriority = priority;
      best = type;
    }
  }

  return best;
}
