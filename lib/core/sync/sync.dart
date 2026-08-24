import 'package:dio/dio.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/conflict_detector.dart';
import 'package:hivorr/core/sync/connectivity_plus_provider.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';
import 'package:hivorr/core/sync/sync_engine.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';

export 'package:hivorr/core/sync/action_queue.dart';
export 'package:hivorr/core/sync/conflict_detector.dart';
export 'package:hivorr/core/sync/connectivity_plus_provider.dart';
export 'package:hivorr/core/sync/connectivity_provider.dart';
export 'package:hivorr/core/sync/sync_action.dart';
export 'package:hivorr/core/sync/sync_action_status.dart';
export 'package:hivorr/core/sync/sync_config.dart';
export 'package:hivorr/core/sync/sync_engine.dart';
export 'package:hivorr/core/sync/sync_exception.dart';
export 'package:hivorr/core/sync/sync_status.dart';
export 'package:hivorr/core/sync/sync_status_provider.dart';

/// Holds the fully wired sync engine artifacts.
///
/// Returned by [initializeSyncEngine] so consumers (bootstrap, repositories)
/// obtain the [SyncEngine] and [SyncStatusProvider] together.
class SyncLayer {
  const SyncLayer({
    required this.engine,
    required this.statusProvider,
  });

  /// The wired sync engine singleton.
  final SyncEngine engine;

  /// The observable sync status provider.
  final SyncStatusProvider statusProvider;
}

/// Bootstraps the offline sync engine from the validated [config].
///
/// Reads [FeatureFlags.enableOfflineSync] — if `false`, returns a no-op
/// engine (all enqueue calls throw [SyncException]). When enabled, constructs
/// the full engine with the provided [StorageEngine] and [Dio] instance
/// (EP-01-12 §5.11).
///
/// EP-01-15 calls this at bootstrap — this function does not modify
/// `main.dart` or bootstrap; it only initializes and returns the engine.
///
/// Pass a custom [connectivityProvider] only for testing; production uses
/// the default [ConnectivityPlusProvider].
Future<SyncLayer> initializeSyncEngine(
  EnvironmentConfig config,
  StorageEngine storageEngine,
  Dio dio, {
  ConnectivityProvider? connectivityProvider,
}) async {
  final bool enabled = config.featureFlags.enableOfflineSync;

  final ConnectivityProvider provider =
      connectivityProvider ?? ConnectivityPlusProvider();

  final SyncStatusProvider statusProvider = SyncStatusProvider();

  final SyncEngine engine = SyncEngine(
    enabled: enabled,
    config: config.syncConfig,
    queue: ActionQueue(
      engine: storageEngine,
      config: config.syncConfig,
    ),
    dio: dio,
    connectivityProvider: provider,
    conflictDetector: const ConflictDetector(),
    statusProvider: statusProvider,
  );

  return SyncLayer(engine: engine, statusProvider: statusProvider);
}
