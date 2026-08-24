import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hivorr/core/database/adapters/hive_storage_engine.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';
import 'package:hivorr/core/sync/sync_exception.dart';

import 'sync_test_helpers.dart';

void main() {
  late Directory tempDir;
  late HiveStorageEngine engine;
  late SyncConfig config;
  late ActionQueue queue;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hivorr_sync_queue_test');
    engine = HiveStorageEngine();
    await engine.initialize(basePath: tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await engine.clearBox('sync_queue');
    config = testSyncConfig(maxQueueDepth: 5, maxRetries: 3);
    queue = ActionQueue(engine: engine, config: config);
  });

  group('ActionQueue — enqueue', () {
    test('persists action with pending status and UUID', () async {
      final action = testAction(endpoint: '/rpc/update');
      final queued = await queue.enqueue(action);

      expect(queued.id, isNotEmpty);
      expect(queued.status, SyncActionStatus.pending);
      expect(queued.endpoint, '/rpc/update');
      expect(queued.retryCount, 0);

      final depth = await queue.depth;
      expect(depth, 1);
    });

    test('assigns default maxRetries when action has zero', () async {
      final action = testAction(maxRetries: 0);
      final queued = await queue.enqueue(action);

      expect(queued.maxRetries, config.defaultMaxRetries);
    });

    test('preserves custom maxRetries when action specifies one', () async {
      final custom = SyncAction(
        id: '',
        type: SyncActionType.update,
        endpoint: '/rpc/test',
        method: 'POST',
        priority: 10,
        status: SyncActionStatus.pending,
        retryCount: 0,
        maxRetries: 7,
        lastKnownVersion: null,
        createdAt: DateTime.now(),
      );
      final queued = await queue.enqueue(custom);

      expect(queued.maxRetries, 7);
    });

    test('rejects enqueue beyond maxQueueDepth', () async {
      for (int i = 0; i < 5; i++) {
        await queue.enqueue(testAction());
      }

      expect(
        () => queue.enqueue(testAction()),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('ActionQueue — dequeue', () {
    test('removes action from queue', () async {
      final queued = await queue.enqueue(testAction());
      await queue.dequeue(queued.id);

      expect(await queue.depth, 0);
    });
  });

  group('ActionQueue — update', () {
    test('updates retryCount and lastAttemptAt', () async {
      final queued = await queue.enqueue(testAction());

      final updated = queued.copyWith(
        status: SyncActionStatus.failed,
        retryCount: 1,
        lastAttemptAt: DateTime.now(),
        errorMessage: 'Network error',
      );
      await queue.update(updated);

      final actions = await queue.peek();
      expect(actions, hasLength(1));
      expect(actions.first.status, SyncActionStatus.failed);
      expect(actions.first.retryCount, 1);
      expect(actions.first.errorMessage, 'Network error');
    });
  });

  group('ActionQueue — peek/drain ordering', () {
    test('returns actions sorted by (priority ASC, createdAt ASC)', () async {
      final now = DateTime.now();

      // Enqueue out of order: priority 10, then 5, then 10 (later).
      await queue.enqueue(SyncAction(
        id: '',
        type: SyncActionType.update,
        endpoint: '/rpc/a',
        method: 'POST',
        priority: 10,
        status: SyncActionStatus.pending,
        retryCount: 0,
        maxRetries: 3,
        createdAt: now.subtract(Duration(seconds: 30)),
      ));
      await queue.enqueue(SyncAction(
        id: '',
        type: SyncActionType.update,
        endpoint: '/rpc/b',
        method: 'POST',
        priority: 5,
        status: SyncActionStatus.pending,
        retryCount: 0,
        maxRetries: 3,
        createdAt: now.subtract(Duration(seconds: 10)),
      ));
      await queue.enqueue(SyncAction(
        id: '',
        type: SyncActionType.update,
        endpoint: '/rpc/c',
        method: 'POST',
        priority: 10,
        status: SyncActionStatus.pending,
        retryCount: 0,
        maxRetries: 3,
        createdAt: now.subtract(Duration(seconds: 5)),
      ));

      final actions = await queue.peek();

      // Expected order: priority 5 (b), then priority 10 older (a), then 10 newer (c).
      expect(actions.map((a) => a.endpoint), <String>['/rpc/b', '/rpc/a', '/rpc/c']);
    });

    test('excludes inFlight, deadLettered, and conflicted actions', () async {
      await queue.enqueue(testAction(endpoint: '/rpc/pending'));
      final queued2 = await queue.enqueue(testAction(endpoint: '/rpc/inflight'));
      final queued3 = await queue.enqueue(testAction(endpoint: '/rpc/dead'));
      final queued4 = await queue.enqueue(testAction(endpoint: '/rpc/conflict'));

      await queue.update(queued2.copyWith(status: SyncActionStatus.inFlight));
      await queue.update(queued3.copyWith(status: SyncActionStatus.deadLettered));
      await queue.update(queued4.copyWith(status: SyncActionStatus.conflicted));

      final actions = await queue.peek();

      // Only pending/failed actions returned.
      expect(actions, hasLength(1));
      expect(actions.first.endpoint, '/rpc/pending');
    });

    test('includes failed actions (retryable)', () async {
      final queued = await queue.enqueue(testAction());
      await queue.update(queued.copyWith(status: SyncActionStatus.failed));

      final actions = await queue.peek();
      expect(actions, hasLength(1));
      expect(actions.first.status, SyncActionStatus.failed);
    });

    test('empty queue returns empty list', () async {
      final actions = await queue.peek();
      expect(actions, isEmpty);
    });
  });

  group('ActionQueue — counts', () {
    test('depth returns total entries (all statuses)', () async {
      await queue.enqueue(testAction());
      final q2 = await queue.enqueue(testAction());
      await queue.enqueue(testAction());

      await queue.update(q2.copyWith(status: SyncActionStatus.deadLettered));

      expect(await queue.depth, 3);
    });

    test('pendingCount returns only pending + inFlight', () async {
      final q1 = await queue.enqueue(testAction());
      final q2 = await queue.enqueue(testAction());

      await queue.update(q1.copyWith(status: SyncActionStatus.inFlight));
      await queue.update(q2.copyWith(status: SyncActionStatus.deadLettered));

      expect(await queue.pendingCount, 1);
    });

    test('deadLetterCount returns deadLettered + conflicted actions', () async {
      final q1 = await queue.enqueue(testAction());
      final q2 = await queue.enqueue(testAction());

      await queue.update(q1.copyWith(status: SyncActionStatus.deadLettered));
      await queue.update(q2.copyWith(status: SyncActionStatus.conflicted));

      expect(await queue.deadLetterCount, 2);
    });
  });

  group('SyncAction — serialization', () {
    test('toJson/fromJson round-trips all fields', () {
      final original = SyncAction(
        id: 'test-uuid',
        type: SyncActionType.update,
        endpoint: '/rpc/update_entity',
        method: 'POST',
        payload: <String, dynamic>{'name': 'Ada', 'age': 30},
        headers: <String, String>{'X-Custom': 'value'},
        priority: 5,
        status: SyncActionStatus.failed,
        retryCount: 2,
        maxRetries: 5,
        lastKnownVersion: 42,
        createdAt: DateTime(2026, 8, 24, 12, 0, 0),
        lastAttemptAt: DateTime(2026, 8, 24, 12, 5, 0),
        errorMessage: 'Network timeout',
      );

      final json = original.toJson();
      final restored = SyncAction.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.endpoint, original.endpoint);
      expect(restored.method, original.method);
      expect(restored.payload, original.payload);
      expect(restored.headers, original.headers);
      expect(restored.priority, original.priority);
      expect(restored.status, original.status);
      expect(restored.retryCount, original.retryCount);
      expect(restored.maxRetries, original.maxRetries);
      expect(restored.lastKnownVersion, original.lastKnownVersion);
      expect(restored.createdAt, original.createdAt);
      expect(restored.lastAttemptAt, original.lastAttemptAt);
      expect(restored.errorMessage, original.errorMessage);
    });

    test('fromJson handles null optional fields', () {
      final json = <String, dynamic>{
        'id': 'test',
        'type': 'create',
        'endpoint': '/rpc/test',
        'method': 'POST',
        'priority': 10,
        'status': 'pending',
        'retryCount': 0,
        'maxRetries': 5,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      };

      final restored = SyncAction.fromJson(json);

      expect(restored.payload, isNull);
      expect(restored.headers, isNull);
      expect(restored.lastKnownVersion, isNull);
      expect(restored.lastAttemptAt, isNull);
      expect(restored.errorMessage, isNull);
    });
  });
}
