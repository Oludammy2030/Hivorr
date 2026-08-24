import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/sync/sync_exception.dart';
import 'package:hivorr/core/sync/sync_status.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';

void main() {
  group('SyncStatusProvider', () {
    late SyncStatusProvider provider;

    setUp(() {
      provider = SyncStatusProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial status is idle', () {
      expect(provider.status, SyncStatus.idle);
    });

    test('initial pendingCount is 0', () {
      expect(provider.pendingCount, 0);
    });

    test('initial deadLetterCount is 0', () {
      expect(provider.deadLetterCount, 0);
    });

    test('initial lastError is null', () {
      expect(provider.lastError, isNull);
    });

    test('setStatus transitions idle -> syncing -> idle', () {
      final transitions = <SyncStatus>[];
      provider.addListener(() {
        transitions.add(provider.status);
      });

      provider.setStatus(SyncStatus.syncing);
      provider.setStatus(SyncStatus.idle);

      expect(transitions, <SyncStatus>[SyncStatus.syncing, SyncStatus.idle]);
    });

    test('setStatus does not notify when value is unchanged', () {
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.setStatus(SyncStatus.idle); // same as initial

      expect(notifyCount, 0);
    });

    test('setStatus transitions idle -> syncing -> error on failure', () {
      final transitions = <SyncStatus>[];
      provider.addListener(() {
        transitions.add(provider.status);
      });

      provider.setStatus(SyncStatus.syncing);
      provider.setError(const SyncException('Drain failed'));

      expect(
        transitions,
        <SyncStatus>[SyncStatus.syncing, SyncStatus.error],
      );
      expect(provider.lastError, isNotNull);
      expect(provider.lastError!.message, 'Drain failed');
    });

    test('setPendingCount updates count and notifies', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setPendingCount(5);

      expect(provider.pendingCount, 5);
      expect(notified, isTrue);
    });

    test('setDeadLetterCount updates count and notifies', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setDeadLetterCount(3);

      expect(provider.deadLetterCount, 3);
      expect(notified, isTrue);
    });

    test('setError sets lastError and status to error', () {
      provider.setStatus(SyncStatus.syncing);
      provider.setError(const SyncException('Network failure'));

      expect(provider.status, SyncStatus.error);
      expect(provider.lastError, isNotNull);
      expect(provider.lastError!.message, 'Network failure');
    });

    test('clearError removes lastError and notifies', () {
      provider.setError(const SyncException('Test error'));
      expect(provider.lastError, isNotNull);

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.clearError();

      expect(provider.lastError, isNull);
      expect(notified, isTrue);
    });

    test('clearError is no-op when no error exists', () {
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.clearError(); // lastError already null

      expect(notifyCount, 0);
    });

    test('setPendingCount does not notify when value unchanged', () {
      provider.setPendingCount(5);

      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.setPendingCount(5); // same value

      expect(notifyCount, 0);
    });

    test('dispose resets all fields', () {
      provider.setStatus(SyncStatus.syncing);
      provider.setPendingCount(10);
      provider.setDeadLetterCount(2);
      provider.setError(const SyncException('Error'));

      provider.dispose();

      expect(provider.status, SyncStatus.idle);
      expect(provider.pendingCount, 0);
      expect(provider.deadLetterCount, 0);
      expect(provider.lastError, isNull);
    });
  });
}
