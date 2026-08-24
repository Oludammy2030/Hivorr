import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hivorr/core/network/network_config.dart';
import 'package:hivorr/core/network/network_status.dart';

/// Abstract interface for network connectivity observation.
///
/// Wraps platform connectivity detection with richer semantics: network
/// type detection, deduplicated status stream, and optional debounce
/// (EP-01-13 §5.5).
///
/// Future phases can replace the default implementation with a richer one
/// (bandwidth estimation, true reachability probing) without modifying
/// consumers (EP-01-13 §5.12).
abstract class NetworkMonitor {
  /// Emits the current [NetworkStatus] whenever it changes (deduplicated).
  Stream<NetworkStatus> get onStatusChanged;

  /// Returns a fresh [NetworkStatus] from a platform connectivity check.
  Future<NetworkStatus> get currentStatus;

  /// Returns the most recently observed [NetworkStatus] without a platform call.
  NetworkStatus get lastKnownStatus;

  /// Releases resources (stream subscriptions, platform handles).
  void dispose();
}

/// Default [NetworkMonitor] backed by the `connectivity_plus` package.
///
/// Applies deduplication (skips emissions where `isConnected` +
/// `networkType` are unchanged) and optional debounce (collapses rapid
/// oscillation into a single emission) (EP-01-13 §5.5).
class ConnectivityPlusNetworkMonitor extends NetworkMonitor {
  ConnectivityPlusNetworkMonitor({
    Connectivity? connectivity,
    required this._config,
  }) : _connectivity = connectivity ?? Connectivity() {
    _controller = StreamController<NetworkStatus>.broadcast();

    unawaited(_checkInitial());

    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error) {
        _controller.addError(error);
      },
    );
  }

  final Connectivity _connectivity;
  final NetworkConfig _config;

  late final StreamController<NetworkStatus> _controller;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  /// The most recently observed status (synchronous cache).
  NetworkStatus _currentSync = NetworkStatus.disconnected();

  Timer? _debounceTimer;

  Future<void> _checkInitial() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final status = NetworkStatus.fromResults(results);
      _currentSync = status;
      _controller.add(status);
    } catch (_) {
      final status = NetworkStatus.disconnected();
      _currentSync = status;
      _controller.add(status);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final status = NetworkStatus.fromResults(results);

    if (_config.debounceIntervalMs > 0) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        Duration(milliseconds: _config.debounceIntervalMs),
        () => _emit(status),
      );
    } else {
      _emit(status);
    }
  }

  void _emit(NetworkStatus status) {
    if (status != _currentSync) {
      _currentSync = status;
      _controller.add(status);
    }
  }

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  Future<NetworkStatus> get currentStatus async {
    final results = await _connectivity.checkConnectivity();
    final status = NetworkStatus.fromResults(results);
    _currentSync = status;
    return status;
  }

  @override
  NetworkStatus get lastKnownStatus => _currentSync;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }
}

/// Test-friendly [NetworkMonitor] with manual state control.
///
/// Allows unit tests to deterministically set network status without
/// relying on platform connectivity APIs (EP-01-13 §5.5).
class FakeNetworkMonitor extends NetworkMonitor {
  FakeNetworkMonitor({NetworkStatus? initial})
      : _current = initial ?? NetworkStatus.disconnected(),
        _controller = StreamController<NetworkStatus>.broadcast() {
    _controller.onListen = () {
      _controller.add(_current);
    };
  }

  final StreamController<NetworkStatus> _controller;
  NetworkStatus _current;

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  Future<NetworkStatus> get currentStatus async => _current;

  @override
  NetworkStatus get lastKnownStatus => _current;

  /// Sets the status and emits to all subscribers (deduplicated).
  void setStatus(NetworkStatus status) {
    if (status != _current) {
      _current = status;
      _controller.add(status);
    }
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}
