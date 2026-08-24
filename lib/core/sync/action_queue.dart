import 'package:hivorr/core/database/boxes/app_boxes.dart';
import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/database/storage_exception.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';
import 'package:hivorr/core/sync/sync_exception.dart';
import 'package:uuid/uuid.dart';

/// Persistent FIFO + priority queue of pending offline mutations.
///
/// Backed by [StorageEngine] using the `sync_queue` box (pre-registered in
/// [AppBoxes.syncQueue]). Enqueue uses atomic [writeBatch] so a crash cannot
/// leave the queue half-written. Drain ordering is `(priority ASC, createdAt
/// ASC)` — lower priority number = higher priority; within the same priority,
/// FIFO by `createdAt` (EP-01-12 §5.4).
class ActionQueue {
  ActionQueue({
    required this._engine,
    required this._config,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final StorageEngine _engine;
  final SyncConfig _config;
  final Uuid _uuid;

  static const String _box = AppBoxes.syncQueue;

  /// Enqueues [action] with a fresh UUID, `pending` status, and `createdAt`.
  ///
  /// Uses [writeBatch] with a single [PutOp] for atomic, crash-safe
  /// persistence. Throws [SyncException] if the queue is at capacity
  /// ([SyncConfig.maxQueueDepth]) or if the storage engine fails.
  Future<SyncAction> enqueue(SyncAction action) async {
    final int depth = await this.depth;
    if (depth >= _config.maxQueueDepth) {
      throw SyncException(
        'Queue depth exceeded (max: ${_config.maxQueueDepth}).',
      );
    }

    final SyncAction queued = SyncAction(
      id: _uuid.v4(),
      type: action.type,
      endpoint: action.endpoint,
      method: action.method,
      payload: action.payload,
      headers: action.headers,
      priority: action.priority,
      status: SyncActionStatus.pending,
      retryCount: 0,
      maxRetries: action.maxRetries > 0
          ? action.maxRetries
          : _config.defaultMaxRetries,
      lastKnownVersion: action.lastKnownVersion,
      createdAt: DateTime.now(),
    );

    try {
      await _engine.writeBatch(
        _box,
        <WriteOp>[PutOp(queued.id, queued.toJson())],
      );
    } on StorageException catch (e) {
      throw SyncException(e.message);
    }

    return queued;
  }

  /// Removes the action with [id] from the queue (called after successful
  /// replay).
  Future<void> dequeue(String id) async {
    try {
      await _engine.delete(_box, id);
    } on StorageException catch (e) {
      throw SyncException(e.message);
    }
  }

  /// Overwrites the action at [id] with [action] (used for retry updates and
  /// dead-lettering).
  Future<void> update(SyncAction action) async {
    try {
      await _engine.put(_box, action.id, action.toJson());
    } on StorageException catch (e) {
      throw SyncException(e.message);
    }
  }

  /// Loads all actions, sorts by `(priority ASC, createdAt ASC)`, and returns
  /// only those eligible for replay (status `pending` or `failed`).
  ///
  /// Status `inFlight`, `deadLettered`, and `conflicted` actions are excluded
  /// from the drain set.
  Future<List<SyncAction>> peek() async {
    final List<String> keys;
    try {
      keys = await _engine.keys(_box);
    } on StorageException catch (e) {
      throw SyncException(e.message);
    }

    final List<SyncAction> actions = <SyncAction>[];
    for (final String key in keys) {
      try {
        final Map<String, dynamic>? raw = await _engine.get(_box, key);
        if (raw != null) {
          actions.add(SyncAction.fromJson(raw));
        }
      } on StorageException catch (e) {
        throw SyncException(e.message);
      }
    }

    actions.sort((SyncAction a, SyncAction b) {
      final int byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      return a.createdAt.compareTo(b.createdAt);
    });

    return actions
        .where(
          (a) =>
              a.status == SyncActionStatus.pending ||
              a.status == SyncActionStatus.failed,
        )
        .toList();
  }

  /// Returns the total number of entries in the queue (all statuses).
  Future<int> get depth async {
    try {
      final List<String> keys = await _engine.keys(_box);
      return keys.length;
    } on StorageException catch (e) {
      throw SyncException(e.message);
    }
  }

  /// Returns the count of dead-lettered actions (deadLettered + conflicted).
  Future<int> get deadLetterCount async {
    final List<SyncAction> all = await _allActions();
    return all
        .where(
          (a) =>
              a.status == SyncActionStatus.deadLettered ||
              a.status == SyncActionStatus.conflicted,
        )
        .length;
  }

  /// Returns the count of pending + inFlight actions.
  Future<int> get pendingCount async {
    final List<SyncAction> all = await _allActions();
    return all
        .where(
          (a) =>
              a.status == SyncActionStatus.pending ||
              a.status == SyncActionStatus.inFlight,
        )
        .length;
  }

  /// Loads all actions (all statuses) without filtering or sorting.
  Future<List<SyncAction>> _allActions() async {
    final List<String> keys;
    try {
      keys = await _engine.keys(_box);
    } on StorageException catch (e) {
      throw SyncException(e.message);
    }

    final List<SyncAction> actions = <SyncAction>[];
    for (final String key in keys) {
      try {
        final Map<String, dynamic>? raw = await _engine.get(_box, key);
        if (raw != null) {
          actions.add(SyncAction.fromJson(raw));
        }
      } on StorageException catch (e) {
        throw SyncException(e.message);
      }
    }
    return actions;
  }
}
