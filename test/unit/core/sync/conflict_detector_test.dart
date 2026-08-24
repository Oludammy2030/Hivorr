import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/sync/conflict_detector.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';

void main() {
  const detector = ConflictDetector();

  group('ConflictDetector', () {
    test('409 with version mismatch flags as conflicted', () {
      final action = testAction(lastKnownVersion: 5);
      final result = detector.detect(action, <String, dynamic>{
        'version': 10,
      });

      expect(result.status, SyncActionStatus.conflicted);
      expect(result.errorMessage, contains('Client version: 5'));
      expect(result.errorMessage, contains('Server version: 10'));
    });

    test('409 without version info still flags as conflicted (conservative)', () {
      final action = testAction(lastKnownVersion: 5);
      final result = detector.detect(action, null);

      expect(result.status, SyncActionStatus.conflicted);
      expect(result.errorMessage, contains('Conflict detected (HTTP 409)'));
      expect(result.errorMessage, contains('Client version: 5'));
      // No server version extracted.
      expect(result.errorMessage, isNot(contains('Server version')));
    });

    test('409 with null lastKnownVersion still flags as conflicted', () {
      final action = testAction(lastKnownVersion: null);
      final result = detector.detect(action, <String, dynamic>{
        'version': 42,
      });

      expect(result.status, SyncActionStatus.conflicted);
      expect(result.errorMessage, contains('Server version: 42'));
      expect(result.errorMessage, isNot(contains('Client version')));
    });

    test('extracts version from server_version field name', () {
      final action = testAction(lastKnownVersion: 1);
      final result = detector.detect(action, <String, dynamic>{
        'server_version': 99,
      });

      expect(result.status, SyncActionStatus.conflicted);
      expect(result.errorMessage, contains('Server version: 99'));
    });

    test('extracts version from current_version field name', () {
      final action = testAction(lastKnownVersion: 1);
      final result = detector.detect(action, <String, dynamic>{
        'current_version': 7,
      });

      expect(result.status, SyncActionStatus.conflicted);
      expect(result.errorMessage, contains('Server version: 7'));
    });

    test('preserves action id and other fields', () {
      final action = SyncAction(
        id: 'abc-123',
        type: SyncActionType.update,
        endpoint: '/rpc/update',
        method: 'POST',
        payload: <String, dynamic>{'k': 'v'},
        priority: 5,
        status: SyncActionStatus.inFlight,
        retryCount: 2,
        maxRetries: 5,
        lastKnownVersion: 3,
        createdAt: DateTime(2026, 1, 1),
      );

      final result = detector.detect(action, <String, dynamic>{
        'version': 9,
      });

      expect(result.id, 'abc-123');
      expect(result.endpoint, '/rpc/update');
      expect(result.payload, <String, dynamic>{'k': 'v'});
      expect(result.priority, 5);
      expect(result.retryCount, 2);
      expect(result.maxRetries, 5);
      expect(result.lastKnownVersion, 3);
      expect(result.createdAt, DateTime(2026, 1, 1));
    });
  });
}

SyncAction testAction({int? lastKnownVersion}) {
  return SyncAction(
    id: 'test-id',
    type: SyncActionType.update,
    endpoint: '/rpc/test',
    method: 'POST',
    priority: 10,
    status: SyncActionStatus.inFlight,
    retryCount: 0,
    maxRetries: 5,
    lastKnownVersion: lastKnownVersion,
    createdAt: DateTime.now(),
  );
}
