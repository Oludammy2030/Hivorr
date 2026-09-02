import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/fake_trade_verification.dart';

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
  const String mimeType = 'application/pdf';
  const String fileName = 'proof.pdf';
  const String professionId = 'p1';
  final ApiException boom = const ApiException(
    kind: ApiExceptionKind.server,
    message: 'boom',
    code: 'X9',
  );

  group('initial state', () {
    test('starts idle with no aggregate', () {
      final provider = TradeVerificationProvider(repo: FakeTradeVerificationRepository());
      expect(provider.submitState, SubmitState.idle);
      expect(provider.status, isNull);
      expect(provider.isSubmitting, isFalse);
      expect(provider.isRefreshing, isFalse);
      expect(provider.submitError, isNull);
      expect(provider.lastError, isNull);
      expect(provider.isAwaitingDecision, isTrue);
      provider.dispose();
    });
  });

  group('submitTradeProof', () {
    test('transitions idle -> submitting -> success and refreshes', () async {
      final provider =
          TradeVerificationProvider(repo: FakeTradeVerificationRepository());
      final states = <SubmitState>[];
      provider.addListener(() => states.add(provider.submitState));

      final future = provider.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(provider.isSubmitting, isTrue);
      await future;

      expect(provider.submitState, SubmitState.success);
      expect(provider.status, isNotNull);
      expect(states, contains(SubmitState.submitting));
      provider.dispose();
    });

    test('stores the error and sets error state on failure', () async {
      final repo = FakeTradeVerificationRepository()..nextError = boom;
      final provider = TradeVerificationProvider(repo: repo);

      await provider.submitTradeProof(
        type: TradeProofType.license,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(provider.submitState, SubmitState.error);
      expect(provider.submitError, boom);
      provider.dispose();
    });

    test('does not start a second submit while one is in flight', () async {
      final repo = FakeTradeVerificationRepository();
      final provider = TradeVerificationProvider(repo: repo);

      final first = provider.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await provider.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await first;

      expect(repo.submitCallCount, 1);
      provider.dispose();
    });
  });

  group('refreshStatus', () {
    test('populates the aggregate and clears error', () async {
      final provider =
          TradeVerificationProvider(repo: FakeTradeVerificationRepository());
      await provider.refreshStatus();

      expect(provider.status, isNotNull);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('sets lastError on failure', () async {
      final repo = FakeTradeVerificationRepository()..nextError = boom;
      final provider = TradeVerificationProvider(repo: repo);

      await provider.refreshStatus();

      expect(provider.lastError, boom);
      expect(provider.status, isNull);
      provider.dispose();
    });
  });

  group('polling', () {
    test('startPolling ticks every 15s while awaiting a decision', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeTradeVerificationRepository(defaultStatus: 'pending');
        final provider = TradeVerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        final callsAtStart = repo.statusCallCount;

        async.elapse(const Duration(seconds: 14));
        expect(repo.statusCallCount, callsAtStart);

        async.elapse(const Duration(seconds: 1));
        expect(repo.statusCallCount, greaterThan(callsAtStart));
        provider.dispose();
      });
    });

    test('startPolling stops ticking once every profession is terminal',
        () {
      fakeAsync((FakeAsync async) {
        final repo = FakeTradeVerificationRepository(defaultStatus: 'approved');
        final provider = TradeVerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();

        async.elapse(const Duration(seconds: 120));
        expect(repo.statusCallCount, 1);
        provider.dispose();
      });
    });

    test('pausePolling stops ticking and resumePolling restarts it', () {
      fakeAsync((FakeAsync async) {
        final repo = FakeTradeVerificationRepository(defaultStatus: 'pending');
        final provider = TradeVerificationProvider(
          repo: repo,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        provider.pausePolling();
        final countAfterPause = repo.statusCallCount;

        async.elapse(const Duration(seconds: 60));
        expect(repo.statusCallCount, countAfterPause);

        provider.resumePolling();
        async.elapse(const Duration(seconds: 15));
        expect(repo.statusCallCount, greaterThan(countAfterPause));
        provider.dispose();
      });
    });
  });

  group('decision notifications', () {
    NotificationProvider buildNotificationProvider(FakeNotificationService service) {
      return NotificationProvider(
        service,
        NotificationPermissionManager(
          platform: FakeNotificationPermissionPlatform(
              nextStatus: NotificationPermissionStatus.granted),
        ),
      );
    }

    test('notifies once when a profession becomes approved', () async {
      final service = FakeNotificationService();
      final repo = FakeTradeVerificationRepository();
      final provider = TradeVerificationProvider(
        repo: repo,
        notificationProvider: buildNotificationProvider(service),
      );

      await provider.refreshStatus();
      repo.setStatus(tradeStatusEntity(
        statuses: <String, String>{'p1': 'approved'},
      ));
      await provider.refreshStatus();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.title, 'Trade verification approved');
      provider.dispose();
    });

    test('notifies once when a profession is rejected (derived)', () async {
      final service = FakeNotificationService();
      final repo = FakeTradeVerificationRepository(defaultStatus: 'unverified');
      final provider = TradeVerificationProvider(
        repo: repo,
        notificationProvider: buildNotificationProvider(service),
      );

      repo.setStatus(tradeStatusEntity(
        statuses: <String, String>{'p1': 'rejected'},
      ));
      await provider.refreshStatus();
      await provider.refreshStatus();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.title,
          'Trade verification requires attention');
      provider.dispose();
    });

    test('does not re-notify the same transition', () async {
      final service = FakeNotificationService();
      final repo = FakeTradeVerificationRepository();
      final provider = TradeVerificationProvider(
        repo: repo,
        notificationProvider: buildNotificationProvider(service),
      );

      repo.setStatus(tradeStatusEntity(
        statuses: <String, String>{'p1': 'approved'},
      ));
      await provider.refreshStatus();
      await provider.refreshStatus();

      expect(service.shown, hasLength(1));
      provider.dispose();
    });
  });

  group('isAwaitingDecision', () {
    test('false when every profession is terminal', () async {
      final repo = FakeTradeVerificationRepository(defaultStatus: 'approved');
      final provider = TradeVerificationProvider(repo: repo);
      await provider.refreshStatus();

      expect(provider.isAwaitingDecision, isFalse);
      provider.dispose();
    });

    test('true while any profession is pending', () async {
      final repo = FakeTradeVerificationRepository(defaultStatus: 'pending');
      final provider = TradeVerificationProvider(repo: repo);
      await provider.refreshStatus();

      expect(provider.isAwaitingDecision, isTrue);
      provider.dispose();
    });

    test('true when the aggregate is absent', () {
      final provider = TradeVerificationProvider(repo: FakeTradeVerificationRepository());
      expect(provider.isAwaitingDecision, isTrue);
      provider.dispose();
    });
  });
}
