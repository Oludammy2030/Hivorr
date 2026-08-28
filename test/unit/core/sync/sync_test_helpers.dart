import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';

export '../../../support/fakes/fake_api.dart';

/// Builds a [SyncConfig] with small values for fast unit tests.
SyncConfig testSyncConfig({
  int maxQueueDepth = 10,
  int maxRetries = 3,
  int drainBatchSize = 5,
}) {
  return SyncConfig(
    maxQueueDepth: maxQueueDepth,
    defaultMaxRetries: maxRetries,
    baseDelay: const Duration(milliseconds: 10),
    maxDelay: const Duration(milliseconds: 100),
    jitterMax: const Duration(milliseconds: 10),
    defaultPriority: 10,
    drainBatchSize: drainBatchSize,
  );
}

/// Creates a [SyncAction] with sensible defaults for tests.
SyncAction testAction({
  String endpoint = '/rpc/test',
  String method = 'POST',
  SyncActionType type = SyncActionType.update,
  int priority = 10,
  Map<String, dynamic>? payload,
  int? lastKnownVersion,
  int maxRetries = 0,
  String id = '',
}) {
  return SyncAction(
    id: id,
    type: type,
    endpoint: endpoint,
    method: method,
    payload: payload,
    priority: priority,
    status: SyncActionStatus.pending,
    retryCount: 0,
    maxRetries: maxRetries,
    lastKnownVersion: lastKnownVersion,
    createdAt: DateTime.now(),
  );
}
