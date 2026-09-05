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
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/finance/fake_escrow_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );

  EscrowProvider build({
    FakeEscrowRepository? repo,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
    HivorrLogger? logger,
  }) {
    final r = repo ?? FakeEscrowRepository();
    return EscrowProvider(
      service: EscrowService(repository: r),
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
    test('starts idle with empty lists and no error', () {
      final provider = build();
      expect(provider.loadState, EscrowLoadState.idle);
      expect(provider.escrows, isEmpty);
      expect(provider.selected, isNull);
      expect(provider.milestones, isEmpty);
      expect(provider.transactionsByEscrowId, isEmpty);
      expect(provider.lastError, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.writeAvailable, isFalse);
      provider.dispose();
    });

    test('writeAvailable reflects the repository seam at construction', () {
      final on = build(repo: FakeEscrowRepository(writeAvailable: true));
      final off = build(repo: FakeEscrowRepository(writeAvailable: false));
      expect(on.writeAvailable, isTrue);
      expect(off.writeAvailable, isFalse);
      on.dispose();
      off.dispose();
    });
  });

  group('loadForProject', () {
    test('populates escrow headers on success', () async {
      final repo = FakeEscrowRepository(
        headers: <Escrow>[seedEscrowEntity(id: 'escrow-1')],
      );
      final provider = build(repo: repo);
      await provider.loadForProject(projectId: 'project-x', escrowIds: const <String>[]);

      expect(provider.loadState, EscrowLoadState.loaded);
      expect(provider.isLoaded, isTrue);
      expect(provider.escrows, hasLength(1));
      expect(provider.escrows.single.id, 'escrow-1');
      expect(repo.getByProjectCallCount, 1);
      provider.dispose();
    });

    test('stores error and loads nothing when the read fails', () async {
      final repo = FakeEscrowRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final provider = build(repo: repo);
      await provider.loadForProject(projectId: 'project-x', escrowIds: const <String>[]);

      expect(provider.loadState, EscrowLoadState.error);
      expect(provider.escrows, isEmpty);
      expect(provider.lastError, isNotNull);
      provider.dispose();
    });
  });

  group('select', () {
    test('loads the escrow detail and memoizes transactions by id', () async {
      final repo = FakeEscrowRepository(
        detail: seedEscrowDetailEntity(
          id: 'escrow-1',
          status: 'partially_released',
          milestones: <EscrowMilestone>[
            seedMilestoneEntity(id: 'ms-1', status: 'released'),
            seedMilestoneEntity(
              id: 'ms-2',
              milestoneNumber: 2,
              sortOrder: 2,
              status: 'pending',
            ),
          ],
          transactions: <EscrowTransaction>[
            seedTransactionEntity(reference: 'RELEASE-1'),
          ],
        ),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');

      expect(provider.selected, isNotNull);
      expect(provider.selected!.status, 'partially_released');
      expect(provider.milestones, hasLength(2));
      expect(provider.milestones.first.isReleased, isTrue);
      expect(provider.transactionsByEscrowId['escrow-1'], hasLength(1));
      expect(repo.getByIdCallCount, 1);
      provider.dispose();
    });

    test('stores error when detail load fails', () async {
      final repo = FakeEscrowRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'no',
          code: 'PLT004',
        );
      final provider = build(repo: repo);
      await provider.select('escrow-1');

      expect(provider.loadState, EscrowLoadState.error);
      expect(provider.selected, isNull);
      expect(provider.lastError!.code, 'PLT004');
      provider.dispose();
    });
  });

  group('refresh', () {
    test('is a no-op without a selection', () async {
      final repo = FakeEscrowRepository();
      final provider = build(repo: repo);
      await provider.refresh();
      expect(repo.getByIdCallCount, 0);
      provider.dispose();
    });

    test('re-reads the current selection', () async {
      final repo = FakeEscrowRepository(
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');
      final callsAfterSelect = repo.getByIdCallCount;

      await provider.refresh();
      expect(repo.getByIdCallCount, callsAfterSelect + 1);
      provider.dispose();
    });

    test('skips refresh while the app is backgrounded (lifecycle gate)',
        () async {
      final repo = FakeEscrowRepository(
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');
      final callsAfterSelect = repo.getByIdCallCount;

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await provider.refresh();
      expect(repo.getByIdCallCount, callsAfterSelect);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      provider.dispose();
    });
  });

  group('write actions', () {
    test('createEscrow applies the re-read detail', () async {
      final repo = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(
          id: 'escrow-9',
          status: 'created',
        ),
      );
      final provider = build(repo: repo);
      final EscrowDetail result = await provider.createEscrow(
        payerEntityId: 'p',
        payeeEntityId: 'ee',
        currencyCode: 'NGN',
        totalAmount: 50000,
        milestones: const <EscrowMilestoneInput>[],
      );

      expect(result.escrow.id, 'escrow-9');
      expect(provider.selected!.id, 'escrow-9');
      expect(repo.createCallCount, 1);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('completeMilestone without selection throws PLT003', () async {
      final provider = build(repo: FakeEscrowRepository(writeAvailable: true));

      await expectLater(
        provider.completeMilestone(milestoneId: 'ms-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      provider.dispose();
    });

    test('completeMilestone applies the re-read detail on success', () async {
      final repo = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(
          id: 'escrow-1',
          status: 'released',
          milestones: <EscrowMilestone>[
            seedMilestoneEntity(id: 'ms-1', status: 'released'),
          ],
        ),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');

      final EscrowDetail detail =
          await provider.completeMilestone(milestoneId: 'ms-1');

      expect(detail.escrow.status, 'released');
      expect(provider.milestones.single.isReleased, isTrue);
      expect(repo.completeMilestoneCallCount, 1);
      provider.dispose();
    });

    test('write actions surface the seam exception when write unavailable',
        () async {
      final repo = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');

      await expectLater(
        provider.completeMilestone(milestoneId: 'ms-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.forbidden,
              )
              .having((ApiException e) => e.message, 'message', contains('support team')),
        ),
      );
      await expectLater(
        provider.releaseMilestone(milestoneId: 'ms-1'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        provider.releaseFinal(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        provider.refundEscrow(reason: 'no'),
        throwsA(isA<ApiException>()),
      );
      provider.dispose();
    });

    test('releaseFinal with notifications wired posts a local notification',
        () async {
      final service = FakeNotificationService();
      final notifications = buildNotifications(service);
      final repo = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(
          id: 'escrow-1',
          status: 'released',
          releasedAmount: 50000,
          milestones: <EscrowMilestone>[
            seedMilestoneEntity(id: 'ms-1', status: 'released'),
          ],
        ),
      );
      final provider = build(
        repo: repo,
        notificationProvider: notifications,
        clock: () => DateTime.fromMillisecondsSinceEpoch(2000),
      );
      await provider.select('escrow-1');
      await provider.releaseFinal();
      await pumpEventQueue();

      expect(service.shown, hasLength(1));
      final HivorrNotification shown = service.shown.single;
      expect(shown.channelId, 'hivorr_default');
      expect(shown.actionRoute, '/finance/escrow/escrow-1');
      expect(shown.title, 'Milestone released');
      expect(shown.body, contains('₦50,000.00'));
      notifications.dispose();
      provider.dispose();
    });
  });

  group('structured logging', () {
    test('loadForProject failure logs a warning with redacted context',
        () async {
      final sink = RecordingSink();
      final repo = FakeEscrowRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final provider = build(repo: repo, logger: makeLogger(sink));

      await provider.loadForProject(
        projectId: 'project-x',
        escrowIds: const <String>[],
      );

      expect(
        sink.entries.map((e) => e.message),
        contains('Escrow list load failed'),
      );
      provider.dispose();
    });

    test('select failure logs a warning with redacted context', () async {
      final sink = RecordingSink();
      final repo = FakeEscrowRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'no',
          code: 'PLT004',
        );
      final provider = build(repo: repo, logger: makeLogger(sink));

      await provider.select('escrow-1');

      expect(
        sink.entries.map((e) => e.message),
        contains('Escrow detail load failed'),
      );
      provider.dispose();
    });

    test('refresh failure logs a warning with redacted context', () async {
      final sink = RecordingSink();
      final repo = FakeEscrowRepository(
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = build(repo: repo, logger: makeLogger(sink));
      await provider.select('escrow-1');
      repo.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'conflict',
        code: 'PLT005',
      );

      await provider.refresh();

      expect(
        sink.entries.map((e) => e.message),
        contains('Escrow refresh failed'),
      );
      provider.dispose();
    });
  });

  group('write actions without a selection', () {
    test('releaseMilestone / releaseFinal / refundEscrow throw PLT003',
        () async {
      final provider = build(repo: FakeEscrowRepository(writeAvailable: true));

      await expectLater(
        provider.releaseMilestone(milestoneId: 'ms-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'releaseMilestone code',
            'PLT003',
          ),
        ),
      );
      await expectLater(
        provider.releaseFinal(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'releaseFinal code',
            'PLT003',
          ),
        ),
      );
      await expectLater(
        provider.refundEscrow(reason: 'missing'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'refundEscrow code',
            'PLT003',
          ),
        ),
      );
      provider.dispose();
    });
  });

  group('write actions on a selected escrow', () {
    test('refundEscrow applies the re-read detail on success', () async {
      final repo = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(id: 'escrow-1', status: 'refunded'),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');

      final EscrowDetail result =
          await provider.refundEscrow(reason: 'No delivery');

      expect(result.escrow.status, 'refunded');
      expect(provider.selected!.status, 'refunded');
      expect(repo.refundCallCount, 1);
      provider.dispose();
    });
  });

  group('refresh in-flight', () {
    test('exposes isRefreshing while the re-read is pending and clears after',
        () async {
      final repo = _PausableRepo(
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = build(repo: repo);
      await provider.select('escrow-1');

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

  group('milestone release notifications', () {
    EscrowProvider buildNotifying({
      required EscrowDetail detail,
      required FakeNotificationService service,
    }) {
      return build(
        repo: FakeEscrowRepository(writeAvailable: true, detail: detail),
        notificationProvider: buildNotifications(service),
        clock: () => DateTime.fromMillisecondsSinceEpoch(2000),
      );
    }

    test('completeMilestone posts a notification with the milestone ordinal',
        () async {
      final service = FakeNotificationService();
      final detail = seedEscrowDetailEntity(
        id: 'escrow-1',
        status: 'partially_released',
        releasedAmount: 50000,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(id: 'ms-1', status: 'released'),
          seedMilestoneEntity(
            id: 'ms-2',
            milestoneNumber: 2,
            sortOrder: 2,
            status: 'pending',
          ),
        ],
      );
      final provider = buildNotifying(detail: detail, service: service);
      await provider.select('escrow-1');
      await provider.completeMilestone(milestoneId: 'ms-1');
      await pumpEventQueue();

      final HivorrNotification shown = service.shown.single;
      expect(shown.title, 'Escrow updated');
      expect(shown.body, contains('milestone 1 of 2'));
      expect(shown.actionRoute, '/finance/escrow/escrow-1');
      provider.dispose();
    });

    test('an unknown milestone id falls back to the list length', () async {
      final service = FakeNotificationService();
      final detail = seedEscrowDetailEntity(
        id: 'escrow-1',
        status: 'released',
        releasedAmount: 50000,
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(id: 'ms-1', status: 'released'),
        ],
      );
      final provider = buildNotifying(detail: detail, service: service);
      await provider.select('escrow-1');
      await provider.completeMilestone(milestoneId: 'ms-999');
      await pumpEventQueue();

      final HivorrNotification shown = service.shown.single;
      expect(shown.body, '₦50,000.00 released to provider — milestone 1 of 1');
      provider.dispose();
    });

    test('a milestone-less release uses the flat body', () async {
      final service = FakeNotificationService();
      final detail = seedEscrowDetailEntity(
        id: 'escrow-1',
        status: 'released',
        releasedAmount: 50000,
        milestones: const <EscrowMilestone>[],
      );
      final provider = buildNotifying(detail: detail, service: service);
      await provider.select('escrow-1');
      await provider.releaseFinal();
      await pumpEventQueue();

      expect(service.shown.single.body, '₦50,000.00 released to provider');
      provider.dispose();
    });
  });
}

/// [FakeEscrowRepository] whose [getById] can be stalled by a [gate]
/// [Completer], letting tests observe in-flight provider refresh state.
class _PausableRepo extends FakeEscrowRepository {
  _PausableRepo({required EscrowDetail detail})
      : super(writeAvailable: true, detail: detail);

  Completer<void>? gate;

  @override
  Future<EscrowDetail> getById(String id) async {
    if (gate != null) await gate!.future;
    return super.getById(id);
  }
}