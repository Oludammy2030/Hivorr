import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hivorr/core/network/network_type.dart';

/// A transient observation of the device's network state.
///
/// Carries only the connectivity flag, network type, and observation
/// timestamp. Contains no business logic, no user data, and no device
/// identifiers (SSID, BSSID, IP, MAC) (EP-01-13 §5.4, §12).
///
/// Value equality is based on [isConnected] + [networkType] only; the
/// [timestamp] is intentionally excluded so deduplication can suppress
/// non-material repeated events (EP-01-13 §5.5).
class NetworkStatus {
  const NetworkStatus({
    required this.isConnected,
    required this.networkType,
    required this.timestamp,
  });

  /// `true` if any network interface is active.
  final bool isConnected;

  /// The primary active network interface (priority-selected).
  final NetworkType networkType;

  /// When this status was observed.
  final DateTime timestamp;

  /// Builds a [NetworkStatus] from `connectivity_plus` results using
  /// priority-based interface selection (EP-01-13 §5.4).
  factory NetworkStatus.fromResults(List<ConnectivityResult> results) {
    final type = selectPrimaryNetworkType(results);
    return NetworkStatus(
      isConnected: type != NetworkType.none,
      networkType: type,
      timestamp: DateTime.now(),
    );
  }

  /// Convenience for a disconnected status (EP-01-13 §5.4).
  factory NetworkStatus.disconnected() {
    return NetworkStatus(
      isConnected: false,
      networkType: NetworkType.none,
      timestamp: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkStatus &&
        other.isConnected == isConnected &&
        other.networkType == networkType;
  }

  @override
  int get hashCode => Object.hash(isConnected, networkType);

  /// Safe string representation — no device identifiers or SSID (EP-01-13 §12).
  @override
  String toString() {
    return 'NetworkStatus(isConnected: $isConnected, '
        'networkType: $networkType)';
  }
}
