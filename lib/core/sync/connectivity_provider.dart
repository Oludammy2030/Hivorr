import 'dart:async';

/// The connectivity state observed by the sync engine.
enum ConnectivityStatus {
  online,
  offline,
}

/// Abstraction over platform connectivity detection.
///
/// The sync engine depends on this interface, not on any specific package,
/// so EP-01-13 (Network Management) can later provide a richer implementation
/// (network type detection, payload optimization) without modifying
/// `SyncEngine` (EP-01-12 §5.7).
abstract class ConnectivityProvider {
  /// Emits the current connectivity status whenever it changes.
  Stream<ConnectivityStatus> get onConnectivityChanged;

  /// Returns `true` if the device currently has network connectivity.
  Future<bool> get isConnected;

  /// Releases resources (stream subscriptions, platform handles).
  void dispose();
}

/// Test-friendly connectivity provider with manual state control.
///
/// Allows unit tests to deterministically toggle between [online] and
/// [offline] without relying on platform connectivity APIs (EP-01-12 §5.7).
class ManualConnectivityProvider implements ConnectivityProvider {
  ManualConnectivityProvider({ConnectivityStatus initial = ConnectivityStatus.online})
      : _controller = StreamController<ConnectivityStatus>.broadcast(),
        _current = initial {
    // Emit the initial status to new subscribers.
    _controller.onListen = () {
      _controller.add(_current);
    };
  }

  final StreamController<ConnectivityStatus> _controller;
  ConnectivityStatus _current;

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async =>
      _current == ConnectivityStatus.online;

  /// Sets the status to [online] and emits to all subscribers.
  void setOnline() {
    _current = ConnectivityStatus.online;
    _controller.add(ConnectivityStatus.online);
  }

  /// Sets the status to [offline] and emits to all subscribers.
  void setOffline() {
    _current = ConnectivityStatus.offline;
    _controller.add(ConnectivityStatus.offline);
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}
