import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status.dart';
import 'package:hivorr/core/network/network_type.dart';

/// App-wide observable network status (EP-01-13 §5.6).
///
/// A [ChangeNotifier] that subscribes to [NetworkMonitor] and exposes the
/// current [NetworkStatus] plus convenience accessors for downstream
/// consumers (EP-01-15 router, EP-01-16 UI, EP-02+ features).
class NetworkStatusProvider extends ChangeNotifier {
  NetworkStatusProvider(this._monitor) : _status = _monitor.lastKnownStatus {
    _subscription = _monitor.onStatusChanged.listen(
      _onStatusChanged,
      onError: (Object error) {
        // Retain last known status on stream errors; monitor remains
        // functional for manual currentStatus queries (EP-01-13 §2.4).
      },
    );
  }

  final NetworkMonitor _monitor;
  late StreamSubscription<NetworkStatus> _subscription;

  NetworkStatus _status;

  /// The current network status (last observed).
  NetworkStatus get status => _status;

  /// Convenience: whether the device is connected.
  bool get isConnected => _status.isConnected;

  /// Convenience: the primary active network type.
  NetworkType get networkType => _status.networkType;

  /// `true` if the current connection is metered (`mobile` or `bluetooth`).
  bool get isOnMeteredConnection {
    final type = _status.networkType;
    return type == NetworkType.mobile || type == NetworkType.bluetooth;
  }

  void _onStatusChanged(NetworkStatus newStatus) {
    if (newStatus != _status) {
      _status = newStatus;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
