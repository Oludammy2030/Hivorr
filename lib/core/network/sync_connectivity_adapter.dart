import 'dart:async';

import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';

/// Bridges the richer [NetworkMonitor] to EP-01-12's [ConnectivityProvider]
/// interface, enabling the sync engine to optionally consume the network
/// layer without modifying EP-01-12 code (EP-01-13 §5.7).
///
/// Maps [NetworkStatus.isConnected] to [ConnectivityStatus]:
///   - `true` → [ConnectivityStatus.online]
///   - `false` → [ConnectivityStatus.offline]
class SyncConnectivityAdapter implements ConnectivityProvider {
  SyncConnectivityAdapter(this._monitor);

  final NetworkMonitor _monitor;

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged {
    return _monitor.onStatusChanged.map(
      (NetworkStatus s) => s.isConnected
          ? ConnectivityStatus.online
          : ConnectivityStatus.offline,
    );
  }

  @override
  Future<bool> get isConnected async =>
      (await _monitor.currentStatus).isConnected;

  /// No-op — the [NetworkMonitor] lifecycle is owned by [NetworkLayer].
  @override
  void dispose() {}
}
