import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/support/fake_dispute_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );

  DisputeProvider build({
    FakeDisputeRepository? repo,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
    HivorrLogger? logger,
  }) {
    final r = repo ?? FakeDisputeRepository();
    return DisputeProvider(
      service: DisputeService(repository: r),
      logger: logger,
      notificationProvider: notificationProvider,
      clock: clock,
    );
  }

  NotificationProvider buildNotifications(FakeNotificationService service) =>
      NotificationProvider(
        service,
        NotificationPermissionManager(
          platform: FakeNotificationPermissionPlatform(
            nextStatus: NotificationPermissionStatus.granted,
          ),
        ),
      );

  group('initial state', () {
    test('starts idle with empty list, no selection and no error', () {
      final provider = build();
      expect(provider.loadState, DisputeLoadState.idle);
      expect(provider.disputes, isEmpty);
      expect(provider.selected, isNull);
      expect(provider.evidence, isEmpty);
      expect(provider.resolution, isNull);
      expect(provider.lastError, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.isRefreshing, isFalse);
      provider.dispose();
    });
  });

  group('loadList', () {
    test('populates the dispute list on success', () async {
      final repo = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(id: 'dispute-1', status: 'open'),
          seedDisputeCaseEntity(id: 'dispute-2', status: 'under_review'),
        ],
      );
      final provider = build(repo: repo);
      await provider.loadList();

      expect(provider.loadState, DisputeLoadState.loaded);
      expect(provider.isLoaded, isTrue);
      expect(provider.disputes, hasLength(2));
      expect(repo.listCallCount, 1);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('passes the status filter to the service', () async {
      final repo = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(id: 'dispute-1', status: 'open'),
          seedDisputeCaseEntity(id: 'dispute-2', status: 'closed'),
        ],
      );
      final provider = build(repo: repo);
      await provider.loadList(status: 'open');

      expect(repo.lastStatusFilter, 'open');
      expect(provider.disputes, hasLength(1));
      expect(provider.disputes.single.status, 'open');
      provider.dispose();
    });

    test('stores the error and loads nothing on failure', () async {
      final repo = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final provider = build(repo: repo);
      await provider.loadList();

      expect(provider.loadState, DisputeLoadState.error);
      expect(provider.disputes, isEmpty);
      expect(provider.lastError, isNotNull);
      expect(provider.lastError!.code, 'PLT999');
      provider.dispose();
    });
  });

  group('select', () {
    test('loads case + evidence + resolution in one getCase', () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(
          id: 'dispute-1',
          status: 'under_review',
          evidence: <DisputeEvidence>[
            seedDisputeEvidenceEntity(id: 'ev-1'),
          ],
          resolution: seedDisputeResolutionEntity(),
        ),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');

      expect(provider.selected, isNotNull);
      expect(provider.selected!.id, 'dispute-1');
      expect(provider.selected!.status, 'under_review');
      expect(provider.evidence, hasLength(1));
      expect(provider.resolution, isNotNull);
      expect(provider.resolution!.resolutionType, 'release_to_payee');
      expect(repo.getCaseCallCount, 1);
      provider.dispose();
    });

    test('stores the error when the detail load fails', () async {
      final repo = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'no',
          code: 'PLT004',
        );
      final provider = build(repo: repo);
      await provider.select('dispute-1');

      expect(provider.loadState, DisputeLoadState.error);
      expect(provider.selected, isNull);
      expect(provider.lastError!.code, 'PLT004');
      provider.dispose();
    });

    test('skips the RPC when the same case is already loaded', () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');
      final callsAfterFirst = repo.getCaseCallCount;

      await provider.select('dispute-1');
      expect(repo.getCaseCallCount, callsAfterFirst);
      provider.dispose();
    });
  });

  group('refresh', () {
    test('is a no-op without a selection', () async {
      final repo = FakeDisputeRepository();
      final provider = build(repo: repo);
      await provider.refresh();
      expect(repo.getCaseCallCount, 0);
      provider.dispose();
    });

    test('re-reads the current selection', () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');
      final callsAfterSelect = repo.getCaseCallCount;

      await provider.refresh();
      expect(repo.getCaseCallCount, callsAfterSelect + 1);
      provider.dispose();
    });

    test('skips refresh while the app is backgrounded (lifecycle gate)',
        () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');
      final callsAfterSelect = repo.getCaseCallCount;

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await provider.refresh();
      expect(repo.getCaseCallCount, callsAfterSelect);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      provider.dispose();
    });

    test('exposes isRefreshing while the re-read is pending and clears after',
        () async {
      final repo = _PausableRepo(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');

      repo.gate = Completer<void>();
      final Future<void> refreshing = provider.refresh();
      await pumpEventQueue();
      expect(provider.isRefreshing, isTrue);

      repo.gate!.complete();
      await refreshing;
      expect(provider.isRefreshing, isFalse);
      provider.dispose();
    });
  });

  group('write actions', () {
    test('file selects the filed case with empty evidence and null resolution',
        () async {
      final repo = FakeDisputeRepository();
      final provider = build(repo: repo);
      final DisputeCase filed = await provider.file(
        escrowId: 'escrow-1',
        disputeType: 'milestone_disagreement',
        reason: 'Work did not match the agreed milestone description.',
        desiredOutcome: 'split',
        priority: 'high',
      );

      expect(filed.id, 'dispute-filed-1');
      expect(filed.status, 'open');
      expect(repo.lastEscrowId, 'escrow-1');
      expect(repo.lastDisputeType, 'milestone_disagreement');
      expect(repo.lastDesiredOutcome, 'split');
      expect(repo.lastPriority, 'high');
      expect(provider.selected!.id, 'dispute-filed-1');
      expect(provider.evidence, isEmpty);
      expect(provider.resolution, isNull);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('file posts a local notification with a redacted escrow suffix',
        () async {
      final service = FakeNotificationService();
      final provider = build(
        repo: FakeDisputeRepository(),
        notificationProvider: buildNotifications(service),
        clock: () => DateTime.fromMillisecondsSinceEpoch(2000),
      );
      await provider.file(
        escrowId: 'escrow-1',
        disputeType: 'service_quality',
        reason: 'Work did not match the agreed milestone description.',
      );
      await pumpEventQueue();

      final HivorrNotification shown = service.shown.single;
      expect(shown.channelId, 'hivorr_default');
      expect(shown.title, 'Dispute filed');
      expect(shown.body, contains('now frozen')); // escrow hold
      expect(shown.body, isNot(contains('escrow-1'))); // PII-safe suffix only
      expect(shown.body, contains('***'));
      expect(shown.actionRoute, '/support/disputes/dispute-filed-1');
      provider.dispose();
    });

    test('submitEvidence appends to the selected evidence', () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');
      final DisputeEvidence submitted = await provider.submitEvidence(
        caseId: 'dispute-1',
        evidenceType: 'screenshot',
        title: 'Mismatch screenshot',
        fileUrl: 'entity-filer/dispute-1/abc.jpg',
      );

      expect(submitted.title, 'Mismatch screenshot');
      expect(provider.evidence, hasLength(1));
      expect(provider.evidence.single.fileUrl, 'entity-filer/dispute-1/abc.jpg');
      expect(repo.lastCaseId, 'dispute-1');
      provider.dispose();
    });

    test('withdraw updates the selection to the withdrawn case', () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo);
      await provider.select('dispute-1');
      final DisputeCase updated = await provider.withdraw('dispute-1');

      expect(updated.status, 'withdrawn');
      expect(provider.selected!.status, 'withdrawn');
      expect(repo.withdrawCallCount, 1);
      provider.dispose();
    });

    test('withdraw posts a local notification saying the escrow is unfrozen',
        () async {
      final service = FakeNotificationService();
      final provider = build(
        repo: FakeDisputeRepository(
          detail: seedDisputeDetailEntity(id: 'dispute-1'),
        ),
        notificationProvider: buildNotifications(service),
        clock: () => DateTime.fromMillisecondsSinceEpoch(2000),
      );
      await provider.select('dispute-1');
      await provider.withdraw('dispute-1');
      await pumpEventQueue();

      final HivorrNotification shown = service.shown.single;
      expect(shown.title, 'Dispute withdrawn');
      expect(shown.body, contains('unfrozen'));
      expect(shown.actionRoute, '/support/disputes/dispute-1');
      provider.dispose();
    });
  });

  group('structured logging', () {
    test('loadList failure logs a warning with redacted context', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final provider = build(repo: repo, logger: makeLogger(sink));

      await provider.loadList();

      expect(
        sink.entries.map((e) => e.message),
        contains('Dispute list load failed'),
      );
      provider.dispose();
    });

    test('select failure logs a warning with redacted context', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'no',
          code: 'PLT004',
        );
      final provider = build(repo: repo, logger: makeLogger(sink));

      await provider.select('dispute-1');

      expect(
        sink.entries.map((e) => e.message),
        contains('Dispute detail load failed'),
      );
      provider.dispose();
    });

    test('refresh failure logs a warning with redacted context', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1'),
      );
      final provider = build(repo: repo, logger: makeLogger(sink));
      await provider.select('dispute-1');
      repo.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'conflict',
        code: 'PLT005',
      );

      await provider.refresh();

      expect(
        sink.entries.map((e) => e.message),
        contains('Dispute refresh failed'),
      );
      provider.dispose();
    });
  });

  group('notification channel contract', () {
    test('dispute notifications reuse hivorr_default', () {
      expect(DisputeNotificationChannel.system, 'hivorr_default');
    });
  });
}

/// [FakeDisputeRepository] whose [getCase] can be stalled by a [gate]
/// [Completer], letting tests observe in-flight provider refresh state.
class _PausableRepo extends FakeDisputeRepository {
  _PausableRepo({required DisputeCaseDetail detail}) : super(detail: detail);

  Completer<void>? gate;

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async {
    if (gate != null) await gate!.future;
    return super.getCase(caseId);
  }
}