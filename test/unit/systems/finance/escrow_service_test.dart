import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/finance/fake_escrow_repository.dart';

void main() {
  EscrowService serviceWith({
    required FakeEscrowRepository repository,
  }) =>
      EscrowService(repository: repository);

  group('EscrowService vocabulary + helpers', () {
    late FakeEscrowRepository repository;
    late EscrowService service;

    setUp(() {
      repository = FakeEscrowRepository();
      service = serviceWith(repository: repository);
    });

    test('statusFor resolves codes to the 7-state vocabulary', () {
      expect(service.statusFor('funded')?.label, 'Funded & held');
      expect(service.statusFor('nope'), isNull);
    });

    test('milestoneStatusFor resolves codes to the 3-state vocabulary', () {
      expect(service.milestoneStatusFor('released')?.label, 'Released');
      expect(service.milestoneStatusFor('nope'), isNull);
    });

    test('exposes the full vocabularies statically', () {
      expect(EscrowService.escrowStatusList, hasLength(7));
      expect(
        EscrowService.escrowStatusList
            .map((final status) => status.code),
        containsAll(<String>[
          'created',
          'funded',
          'partially_released',
          'released',
          'refunded',
          'cancelled',
          'disputed',
        ]),
      );
      expect(EscrowService.milestoneStatusList, hasLength(3));
    });

    test('validates milestone sums within the 0.01 tolerance', () {
      expect(
        service.validateMilestoneSums(
          totalAmount: 0,
          milestoneAmounts: const <double>[],
        ),
        isTrue,
      );
      expect(
        service.validateMilestoneSums(
          totalAmount: 50000,
          milestoneAmounts: const <double>[25000, 25000],
        ),
        isTrue,
      );
      expect(
        service.validateMilestoneSums(
          totalAmount: 50000.005,
          milestoneAmounts: const <double>[25000, 25000],
        ),
        isTrue,
      );
    });

    test('rejects milestone sums outside the tolerance', () {
      expect(
        service.validateMilestoneSums(
          totalAmount: 40000,
          milestoneAmounts: const <double>[25000],
        ),
        isFalse,
      );
    });

    test('releasedMilestoneTotal sums only released milestones', () {
      final milestones = <EscrowMilestone>[
        seedMilestoneEntity(status: 'pending'),
        seedMilestoneEntity(id: 'ms-2', status: 'completed'),
        seedMilestoneEntity(id: 'ms-3', status: 'released', amount: 20000),
      ];
      expect(service.releasedMilestoneTotal(milestones), 20000);
    });

    test('completedMilestoneTotal sums completed and released milestones', () {
      final milestones = <EscrowMilestone>[
        seedMilestoneEntity(status: 'pending'),
        seedMilestoneEntity(id: 'ms-2', status: 'completed', amount: 30000),
        seedMilestoneEntity(id: 'ms-3', status: 'released', amount: 20000),
      ];
      expect(service.completedMilestoneTotal(milestones), 50000);
    });

    test('milestoneProgress is 0 for a non-positive total', () {
      expect(
        service.milestoneProgress(
          milestones: const <EscrowMilestone>[],
          totalAmount: 0,
        ),
        0.0,
      );
    });

    test('milestoneProgress returns the released ratio', () {
      final milestones = <EscrowMilestone>[
        seedMilestoneEntity(status: 'released', amount: 25000),
        seedMilestoneEntity(id: 'ms-2', status: 'pending', amount: 25000),
      ];
      expect(
        service.milestoneProgress(milestones: milestones, totalAmount: 50000),
        closeTo(0.5, 0.0001),
      );
    });

    test('milestoneProgress clamps to 1.0 when releases exceed the total', () {
      final milestones = <EscrowMilestone>[
        seedMilestoneEntity(status: 'released', amount: 60000),
      ];
      expect(
        service.milestoneProgress(milestones: milestones, totalAmount: 50000),
        1.0,
      );
    });
  });

  group('EscrowService data operations', () {
    test('getById delegates to the repository', () async {
      final repository = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(id: 'escrow-9'),
      );
      final service = EscrowService(repository: repository);

      final detail = await service.getById('escrow-9');

      expect(repository.getByIdCallCount, 1);
      expect(detail.escrow.id, 'escrow-9');
    });

    test('getByProject delegates with project + id subset', () async {
      final repository = FakeEscrowRepository(
        headers: <Escrow>[seedEscrowEntity(id: 'escrow-1')],
      );
      final service = EscrowService(repository: repository);

      final escrows = await service.getByProject(
        projectId: 'proj-1',
        escrowIds: const <String>['escrow-1'],
      );

      expect(repository.getByProjectCallCount, 1);
      expect(escrows, hasLength(1));
    });

    test('createEscrow delegates and rethrows write failure', () async {
      final repository = FakeEscrowRepository(writeAvailable: false);
      final service = EscrowService(repository: repository);

      await expectLater(
        service.createEscrow(
          payerEntityId: 'payer',
          payeeEntityId: 'payee',
          currencyCode: 'NGN',
          totalAmount: 100000,
          milestones: const [],
        ),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      expect(repository.createCallCount, 1);
    });

    test('completeMilestone delegates with milestone identifier', () async {
      final repository = FakeEscrowRepository(writeAvailable: true);
      final service = EscrowService(repository: repository);

      await service.completeMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1');

      expect(repository.completeMilestoneCallCount, 1);
      expect(repository.lastMilestoneId, 'ms-1');
    });

    test('releaseMilestone / releaseFinal / refund delegate', () async {
      final repository = FakeEscrowRepository(writeAvailable: true);
      final service = EscrowService(repository: repository);

      await service.releaseMilestone(escrowId: 'escrow-1', milestoneId: 'ms-2');
      await service.releaseFinal(escrowId: 'escrow-1');
      await service.refundEscrow(escrowId: 'escrow-1', reason: 'No delivery');

      expect(repository.releaseMilestoneCallCount, 1);
      expect(repository.releaseFinalCallCount, 1);
      expect(repository.refundCallCount, 1);
    });

    test('surfaces repository ApiException as-is', () async {
      final repository = FakeEscrowRepository();
      repository.nextError = const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'boom',
        code: 'PLT004',
        statusCode: 404,
      );
      final service = EscrowService(repository: repository);

      await expectLater(
        service.getById('escrow-1'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.code, 'code', 'PLT004')
            .having(
              (ApiException e) => e.kind,
              'kind',
              ApiExceptionKind.notFound,
            )),
      );
    });
  });

  group('EscrowService instrumentation with logger', () {
    HivorrLogger logged(RecordingSink sink) => HivorrLogger(
          'hivorr.test',
          LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
          PiiRedactor(),
        );

    test('reads log redacted context on success', () async {
      final sink = RecordingSink();
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedEscrowDetailEntity(id: 'escrow-9'),
      );
      final service = EscrowService(
        repository: repository,
        logger: logged(sink),
      );

      await service.getById('escrow-9');
      await service.getByProject(
        projectId: 'proj-1',
        escrowIds: const <String>['escrow-9'],
      );

      expect(
        sink.entries.map((e) => e.message),
        containsAll(<String>[
          'Escrow detail fetched',
          'Escrow list fetched',
        ]),
      );
    });

    test('writes log each transition on success', () async {
      final sink = RecordingSink();
      final repository = FakeEscrowRepository(writeAvailable: true);
      final service = EscrowService(
        repository: repository,
        logger: logged(sink),
      );

      await service.createEscrow(
        payerEntityId: 'payer',
        payeeEntityId: 'payee',
        currencyCode: 'NGN',
        totalAmount: 100000,
        milestones: const <EscrowMilestoneInput>[],
      );
      await service.completeMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1');
      await service.releaseMilestone(escrowId: 'escrow-1', milestoneId: 'ms-2');
      await service.releaseFinal(escrowId: 'escrow-1');
      await service.refundEscrow(escrowId: 'escrow-1', reason: 'No delivery');

      expect(
        sink.entries.map((e) => e.message),
        containsAll(<String>[
          'Creating escrow',
          'Escrow created',
          'Milestone completed',
          'Milestone released',
          'Escrow fully released',
          'Escrow refunded',
        ]),
      );
    });

    test('failure path logs the failing span and rethrows', () async {
      final sink = RecordingSink();
      final repository = FakeEscrowRepository();
      repository.nextError = const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'boom',
        code: 'PLT004',
      );
      final service = EscrowService(
        repository: repository,
        logger: logged(sink),
      );

      await expectLater(
        service.getById('escrow-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT004',
          ),
        ),
      );

      final LogEntry failure = sink.entries.single;
      expect(failure.message, 'finance.escrow.get failed');
      expect(failure.error, isA<ApiException>());
    });
  });
}