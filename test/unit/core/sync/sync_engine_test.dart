import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hivorr/core/database/adapters/hive_storage_engine.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/conflict_detector.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';
import 'package:hivorr/core/sync/sync_engine.dart';
import 'package:hivorr/core/sync/sync_exception.dart';
import 'package:hivorr/core/sync/sync_status.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';

import 'sync_test_helpers.dart';

void main() {
  late Directory tempDir;
  late HiveStorageEngine engine;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hivorr_sync_engine_test');
    engine = HiveStorageEngine();
    await engine.initialize(basePath: tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await engine.clearBox('sync_queue');
  });

  SyncEngine buildEngine({
    required Dio dio,
    required bool enabled,
    required ConnectivityProvider connectivity,
    required SyncStatusProvider statusProvider,
    SyncConfig? config,
  }) {
    final cfg = config ?? testSyncConfig(maxQueueDepth: 10, maxRetries: 3);
    return SyncEngine(
      enabled: enabled,
      config: cfg,
      queue: ActionQueue(engine: engine, config: cfg),
      dio: dio,
      connectivityProvider: connectivity,
      conflictDetector: const ConflictDetector(),
      statusProvider: statusProvider,
    );
  }

  group('SyncEngine — enqueue', () {
    test('persists action when enabled', () async {
      final dio = buildTestDio(ScriptedAdapter(
        (_) async => successBody(),
      ));
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      final queued = await engine_.enqueue(testAction(
        endpoint: '/rpc/create',
        maxRetries: 3,
      ));

      expect(queued.id, isNotEmpty);
      expect(queued.status, SyncActionStatus.pending);
      expect(statusProvider.pendingCount, 1);
    });

    test('throws SyncException when feature gate is disabled', () async {
      final dio = buildTestDio(ScriptedAdapter(
        (_) async => successBody(),
      ));
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: false,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      expect(
        () => engine_.enqueue(testAction(maxRetries: 3)),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('SyncEngine — drain replay success', () {
    test('dequeues action after 2xx response', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(maxRetries: 3));
      await engine_.drain();

      expect(statusProvider.pendingCount, 0);
      expect(statusProvider.status, SyncStatus.idle);
    });

    test('processes multiple actions sequentially', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(endpoint: '/rpc/a', maxRetries: 3));
      await engine_.enqueue(testAction(endpoint: '/rpc/b', maxRetries: 3));
      await engine_.enqueue(testAction(endpoint: '/rpc/c', maxRetries: 3));

      await engine_.drain();

      // All 3 actions replayed (captured by adapter).
      expect(adapter.captured.map((o) => o.path), <String>[
        '/rpc/a',
        '/rpc/b',
        '/rpc/c',
      ]);
      expect(statusProvider.pendingCount, 0);
    });
  });

  group('SyncEngine — transient failure with retry', () {
    test('retries on 500 and succeeds on second attempt', () async {
      var callCount = 0;
      final adapter = ScriptedAdapter((_) async {
        callCount++;
        if (callCount == 1) {
          return errorBody(500);
        }
        return successBody();
      });
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(maxRetries: 3));
      await engine_.drain();

      expect(callCount, 2);
      expect(statusProvider.pendingCount, 0);
    });

    test('dead-letters after max retries exhausted', () async {
      final adapter = ScriptedAdapter(
        (_) async => errorBody(500),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(maxRetries: 3));
      await engine_.drain();

      expect(statusProvider.deadLetterCount, 1);
      expect(adapter.captured.length, 3); // 3 attempts (maxRetries).
    });
  });

  group('SyncEngine — conflict detection (409)', () {
    test('flags action as conflicted and moves to dead-letter', () async {
      final adapter = ScriptedAdapter(
        (_) async => errorBody(409, body: '{"version": 99}'),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(maxRetries: 3, lastKnownVersion: 5));
      await engine_.drain();

      expect(statusProvider.deadLetterCount, 1);
      expect(adapter.captured.length, 1); // No retry on conflict.
    });
  });

  group('SyncEngine — client error (4xx, non-401/409)', () {
    test('dead-letters without retry on 403 Forbidden', () async {
      final adapter = ScriptedAdapter(
        (_) async => errorBody(403),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(maxRetries: 3));
      await engine_.drain();

      expect(statusProvider.deadLetterCount, 1);
      expect(adapter.captured.length, 1); // No retry on client error.
    });

    test('dead-letters without retry on 422 Validation', () async {
      final adapter = ScriptedAdapter(
        (_) async => errorBody(422),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.enqueue(testAction(maxRetries: 3));
      await engine_.drain();

      expect(statusProvider.deadLetterCount, 1);
      expect(adapter.captured.length, 1);
    });
  });

  group('SyncEngine — drain batch size', () {
    test('processes only drainBatchSize actions per cycle', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
        config: testSyncConfig(maxQueueDepth: 10, maxRetries: 3),
      );
      // Override drainBatchSize via a custom config.
      addTearDown(engine_.dispose);

      // Enqueue 7 actions, but drainBatchSize defaults to 5 in testSyncConfig.
      for (int i = 0; i < 7; i++) {
        await engine_.enqueue(testAction(maxRetries: 3));
      }

      await engine_.drain();

      // Only 5 processed in this drain cycle.
      expect(adapter.captured.length, 5);
      // 2 still pending.
      expect(statusProvider.pendingCount, 2);

      // Drain again to clear remaining.
      await engine_.drain();
      expect(adapter.captured.length, 7);
      expect(statusProvider.pendingCount, 0);
    });
  });

  group('SyncEngine — drain with empty queue', () {
    test('no-op when queue is empty', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.drain();

      expect(adapter.captured.length, 0);
      expect(statusProvider.status, SyncStatus.idle);
      expect(statusProvider.pendingCount, 0);
    });
  });

  group('SyncEngine — connectivity-triggered drain', () {
    test('setOnline triggers drain', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider(
        initial: ConnectivityStatus.offline,
      );
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      // Enqueue while offline.
      await engine_.enqueue(testAction(maxRetries: 3));

      // Allow the connectivity listener to settle.
      await Future<void>.delayed(Duration.zero);

      // No replay yet (offline).
      expect(adapter.captured.length, 0);

      // Go online — triggers drain.
      connectivity.setOnline();
      await Future<void>.delayed(Duration(milliseconds: 100));

      expect(adapter.captured.length, 1);
      expect(statusProvider.pendingCount, 0);
    });

    test('setOffline sets status to offline', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      // Allow initial online event to settle.
      await Future<void>.delayed(Duration.zero);

      connectivity.setOffline();
      await Future<void>.delayed(Duration.zero);

      expect(statusProvider.status, SyncStatus.offline);
    });
  });

  group('SyncEngine — disabled engine', () {
    test('drain is a no-op when disabled', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final connectivity = ManualConnectivityProvider();
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: false,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      await engine_.drain();

      expect(adapter.captured.length, 0);
      // Status should remain idle (no syncing transition).
      expect(statusProvider.status, SyncStatus.idle);
    });
  });

  group('SyncEngine — connectivity stream error', () {
    test('stream error sets status to error; engine remains functional', () async {
      final adapter = ScriptedAdapter(
        (_) async => successBody(),
      );
      final dio = buildTestDio(adapter);
      final controller = StreamController<ConnectivityStatus>();
      final connectivity = _ErrorConnectivityProvider(controller);
      final statusProvider = SyncStatusProvider();
      final engine_ = buildEngine(
        dio: dio,
        enabled: true,
        connectivity: connectivity,
        statusProvider: statusProvider,
      );
      addTearDown(engine_.dispose);

      // Allow initial event to settle.
      await Future<void>.delayed(Duration.zero);

      // Emit an error on the stream.
      controller.addError('Platform connectivity error');
      await Future<void>.delayed(Duration.zero);

      expect(statusProvider.status, SyncStatus.error);
      expect(statusProvider.lastError, isNotNull);
      expect(statusProvider.lastError!.message, contains('Connectivity stream error'));

      // Engine remains functional for manual drain.
      await engine_.enqueue(testAction(maxRetries: 3));
      await engine_.drain();

      expect(adapter.captured.length, 1);
      expect(statusProvider.pendingCount, 0);
    });
  });
}

/// Connectivity provider backed by a [StreamController] for testing stream
/// errors.
class _ErrorConnectivityProvider implements ConnectivityProvider {
  _ErrorConnectivityProvider(this._controller);

  final StreamController<ConnectivityStatus> _controller;

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async => true;

  @override
  void dispose() => _controller.close();
}
