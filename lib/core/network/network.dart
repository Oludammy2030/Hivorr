import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/network/network_config.dart';
import 'package:hivorr/core/network/network_monitor.dart';
import 'package:hivorr/core/network/network_status_provider.dart';
import 'package:hivorr/core/network/payload_optimizer.dart';
import 'package:hivorr/core/network/sync_connectivity_adapter.dart';

export 'package:hivorr/core/network/network_config.dart';
export 'package:hivorr/core/network/network_exception.dart';
export 'package:hivorr/core/network/network_monitor.dart';
export 'package:hivorr/core/network/network_status.dart';
export 'package:hivorr/core/network/network_status_provider.dart';
export 'package:hivorr/core/network/network_type.dart';
export 'package:hivorr/core/network/payload_optimizer.dart';
export 'package:hivorr/core/network/sync_connectivity_adapter.dart';

/// Holds the fully wired network management artifacts.
///
/// Returned by [initializeNetwork] so consumers (bootstrap, sync engine,
/// UI, EP-02+ features) obtain all network artifacts together
/// (EP-01-13 §5.10).
class NetworkLayer {
  const NetworkLayer({
    required this.monitor,
    required this.statusProvider,
    required this.adapter,
    required this.payloadOptimizer,
    required this.config,
  });

  /// Core network detection service.
  final NetworkMonitor monitor;

  /// App-wide observable network status.
  final NetworkStatusProvider statusProvider;

  /// EP-01-12 `ConnectivityProvider` bridge.
  final SyncConnectivityAdapter adapter;

  /// Advisory payload optimization utilities.
  final PayloadOptimizer payloadOptimizer;

  /// Active network configuration.
  final NetworkConfig config;

  /// Releases all resources held by this layer.
  void dispose() {
    statusProvider.dispose();
    monitor.dispose();
  }
}

/// Bootstraps the network management layer from the validated [config].
///
/// Constructs the [NetworkMonitor] with the configured debounce interval,
/// subscribes [NetworkStatusProvider] to the monitor, builds the
/// [PayloadOptimizer] with config thresholds, and creates the
/// [SyncConnectivityAdapter] for EP-01-12 integration (EP-01-13 §5.10).
///
/// EP-01-15 calls this at bootstrap — this function does not modify
/// `main.dart` or bootstrap; it only initializes and returns the layer.
NetworkLayer initializeNetwork(EnvironmentConfig config) {
  final networkConfig = config.networkConfig;

  final monitor = ConnectivityPlusNetworkMonitor(config: networkConfig);

  final statusProvider = NetworkStatusProvider(monitor);

  final payloadOptimizer = PayloadOptimizer(networkConfig);

  final adapter = SyncConnectivityAdapter(monitor);

  return NetworkLayer(
    monitor: monitor,
    statusProvider: statusProvider,
    adapter: adapter,
    payloadOptimizer: payloadOptimizer,
    config: networkConfig,
  );
}
