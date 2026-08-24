import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';

/// Default [ConnectivityProvider] backed by the `connectivity_plus` package.
///
/// Maps `connectivity_plus`'s `ConnectivityResult` to the sync engine's
/// [ConnectivityStatus]. EP-01-13 (Network Management) may later provide a
/// richer implementation with network type detection and payload optimization
/// hooks that replaces this default (EP-01-12 §5.7).
class ConnectivityPlusProvider implements ConnectivityProvider {
  ConnectivityPlusProvider()
      : _connectivity = Connectivity(),
        _controller = StreamController<ConnectivityStatus>.broadcast() {
    _current = _mapResult(_connectivity.checkConnectivity());
    _subscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final ConnectivityStatus status = _mapResultsSync(results);
        if (status != _currentSync) {
          _currentSync = status;
          _controller.add(status);
        }
      },
    );
  }

  final Connectivity _connectivity;
  final StreamController<ConnectivityStatus> _controller;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  /// The most recently observed status (synchronous).
  ConnectivityStatus _currentSync = ConnectivityStatus.online;

  late Future<ConnectivityStatus> _current;

  /// Maps a `Future<ConnectivityResult>` to a [ConnectivityStatus], updating
  /// the synchronous cache.
  Future<ConnectivityStatus> _mapResult(
    Future<List<ConnectivityResult>> future,
  ) async {
    final List<ConnectivityResult> results = await future;
    final ConnectivityStatus status = _mapResultsSync(results);
    _currentSync = status;
    return status;
  }

  /// Maps `connectivity_plus` results to [ConnectivityStatus] synchronously.
  ///
  /// `ConnectivityResult.none` → [offline]; everything else → [online].
  static ConnectivityStatus _mapResultsSync(List<ConnectivityResult> results) {
    if (results.isEmpty ||
        results.every((ConnectivityResult r) => r == ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  }

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async {
    final ConnectivityStatus status = await _current;
    return status == ConnectivityStatus.online;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }
}
