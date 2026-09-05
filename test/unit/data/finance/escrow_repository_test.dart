import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/repositories/escrow_repository_impl.dart';

import '../../../support/fakes/finance/fake_escrow_remote_data_source.dart';

void main() {
  EscrowRepositoryImpl build({
    bool writeViaProxy = false,
    String status = 'funded',
    double releasedAmount = 0,
    List<EscrowMilestoneDto>? milestones,
  }) {
    final List<EscrowMilestoneDto> milestoneList =
        milestones ?? <EscrowMilestoneDto>[
          seedMilestoneDto(id: 'ms-1', status: 'pending'),
        ];
    final FakeEscrowRemoteDataSource remote = FakeEscrowRemoteDataSource(
      writeViaProxy: writeViaProxy,
      details: <String, EscrowDetailDto>{
        'escrow-1': seedDetailDto(
          escrow: seedEscrowDto(
            id: 'escrow-1',
            status: status,
            releasedAmount: releasedAmount,
          ),
          milestones: milestoneList,
        ),
      },
    );
    return EscrowRepositoryImpl(remote: remote);
  }

  EscrowRepositoryImpl seamBuild({required bool writeViaProxy}) =>
      build(writeViaProxy: writeViaProxy);

  group('EscrowRepositoryImpl reads', () {
    test('getById maps the envelope DTO into domain entities', () async {
      final repo = build();

      final EscrowDetail detail = await repo.getById('escrow-1');

      expect(detail.escrow.id, 'escrow-1');
      expect(detail.escrow.status, 'funded');
      expect(detail.escrow.totalAmount, 50000);
      expect(detail.escrow.isActive, isTrue);
      expect(detail.milestones, hasLength(1));
      expect(detail.milestones.single.isPending, isTrue);
      expect(detail.transactions, isEmpty);
    });

    test('getByProject returns headers for the enumerated ids', () async {
      final remote = FakeEscrowRemoteDataSource(
        details: <String, EscrowDetailDto>{
          'escrow-1': seedDetailDto(
            escrow: seedEscrowDto(id: 'escrow-1'),
          ),
          'escrow-2': seedDetailDto(
            escrow: seedEscrowDto(id: 'escrow-2', status: 'released'),
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final List<Escrow> escrows =
          await repo.getByProject(projectId: 'project-x', escrowIds: const <String>[
        'escrow-1',
        'escrow-2',
      ]);

      expect(escrows, hasLength(2));
      expect(escrows[0].id, 'escrow-1');
      expect(escrows[1].status, 'released');
    });

    test('surfaces remote not-found as ApiException', () async {
      final remote = FakeEscrowRemoteDataSource();
      final repo = EscrowRepositoryImpl(remote: remote);

      await expectLater(
        repo.getById('missing'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('EscrowRepositoryImpl write seam off', () {
    test('writeAvailable reflects writeViaProxy', () {
      expect(build(writeViaProxy: false).writeAvailable, isFalse);
      expect(build(writeViaProxy: true).writeAvailable, isTrue);
    });

    test('createEscrow throws with support-team guidance before any write',
        () async {
      final repo = seamBuild(writeViaProxy: false);

      await expectLater(
        repo.createEscrow(
          payerEntityId: 'p',
          payeeEntityId: 'ee',
          currencyCode: 'NGN',
          totalAmount: 50000,
          milestones: const <EscrowMilestoneInput>[],
        ),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
    });

    test('completeMilestone / releaseMilestone / releaseFinal / refundEscrow '
        'throw the seam exception when write unavailable', () async {
      final repo = seamBuild(writeViaProxy: false);

      await expectLater(
        repo.completeMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        repo.releaseMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        repo.releaseFinal(escrowId: 'escrow-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        repo.refundEscrow(escrowId: 'escrow-1', reason: 'no'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
    });
  });

  group('EscrowRepositoryImpl validation (fail-fast PLT003)', () {
    test('createEscrow rejects unsupported currency', () async {
      final repo = seamBuild(writeViaProxy: true);

      await expectLater(
        repo.createEscrow(
          payerEntityId: 'p',
          payeeEntityId: 'ee',
          currencyCode: 'EUR',
          totalAmount: 50000,
          milestones: const <EscrowMilestoneInput>[],
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT003')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              ),
        ),
      );
    });

    test('createEscrow rejects milestone sums that do not equal the total',
        () async {
      final repo = seamBuild(writeViaProxy: true);

      await expectLater(
        repo.createEscrow(
          payerEntityId: 'p',
          payeeEntityId: 'ee',
          currencyCode: 'NGN',
          totalAmount: 50000,
          milestones: const <EscrowMilestoneInput>[
            EscrowMilestoneInput(
              milestoneNumber: 1,
              title: 'Design',
              amount: 30000,
            ),
            EscrowMilestoneInput(
              milestoneNumber: 2,
              title: 'Build',
              amount: 10000,
            ),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
    });

    test('createEscrow accepts sums within the 0.01 tolerance', () async {
      final remote = FakeEscrowRemoteDataSource(
        writeViaProxy: true,
        createEscrowId: 'escrow-created-9',
        details: <String, EscrowDetailDto>{
          'escrow-created-9': seedDetailDto(
            escrow: seedEscrowDto(
              id: 'escrow-created-9',
              status: 'created',
            ),
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final EscrowDetail created = await repo.createEscrow(
        payerEntityId: 'p',
        payeeEntityId: 'ee',
        currencyCode: 'NGN',
        totalAmount: 50000,
        milestones: const <EscrowMilestoneInput>[
          EscrowMilestoneInput(
            milestoneNumber: 1,
            title: 'Design',
            amount: 15000.01,
          ),
          EscrowMilestoneInput(
            milestoneNumber: 2,
            title: 'Build',
            amount: 34999.99,
          ),
        ],
      );

      expect(created.escrow.id, 'escrow-created-9');
      expect(remote.createCallCount, 1);
      expect(remote.getByIdCallCount, 1);
    });
  });

  group('EscrowRepositoryImpl write seam on (proxy success → re-read)', () {
    test('createEscrow returns the re-read created escrow', () async {
      final remote = FakeEscrowRemoteDataSource(
        writeViaProxy: true,
        createEscrowId: 'escrow-created-9',
        details: <String, EscrowDetailDto>{
          'escrow-created-9': seedDetailDto(
            escrow: seedEscrowDto(
              id: 'escrow-created-9',
              status: 'created',
            ),
            milestones: const <EscrowMilestoneDto>[],
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final EscrowDetail detail = await repo.createEscrow(
        payerEntityId: 'p',
        payeeEntityId: 'ee',
        currencyCode: 'NGN',
        totalAmount: 50000,
        milestones: const <EscrowMilestoneInput>[],
      );

      expect(detail.escrow.id, 'escrow-created-9');
      expect(detail.escrow.status, 'created');
      expect(remote.lastCreatePayerEntityId, 'p');
      expect(remote.lastCreatePayeeEntityId, 'ee');
      expect(remote.lastCreateCurrencyCode, 'NGN');
      expect(remote.lastCreateTotalAmount, 50000);
    });

    test('completeMilestone re-reads after proxy success', () async {
      final remote = FakeEscrowRemoteDataSource(
        writeViaProxy: true,
        details: <String, EscrowDetailDto>{
          'escrow-1': seedDetailDto(
            escrow: seedEscrowDto(id: 'escrow-1', status: 'partially_released'),
            milestones: <EscrowMilestoneDto>[
              seedMilestoneDto(id: 'ms-1', status: 'released'),
            ],
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final EscrowDetail detail =
          await repo.completeMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1');

      expect(detail.escrow.status, 'partially_released');
      expect(detail.milestones.single.status, 'released');
      expect(remote.completeMilestoneCallCount, 1);
      expect(remote.lastMilestoneId, 'ms-1');
    });

    test('releaseFinal re-reads the released escrow', () async {
      final remote = FakeEscrowRemoteDataSource(
        writeViaProxy: true,
        details: <String, EscrowDetailDto>{
          'escrow-1': seedDetailDto(
            escrow: seedEscrowDto(
              id: 'escrow-1',
              status: 'released',
              releasedAmount: 50000,
            ),
            milestones: <EscrowMilestoneDto>[
              seedMilestoneDto(id: 'ms-1', status: 'released'),
            ],
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final EscrowDetail detail = await repo.releaseFinal(escrowId: 'escrow-1');

      expect(detail.escrow.status, 'released');
      expect(detail.escrow.releasedAmount, 50000);
      expect(remote.releaseFinalCallCount, 1);
    });

    test('releaseMilestone re-reads after proxy success', () async {
      final remote = FakeEscrowRemoteDataSource(
        writeViaProxy: true,
        details: <String, EscrowDetailDto>{
          'escrow-1': seedDetailDto(
            escrow: seedEscrowDto(
              id: 'escrow-1',
              status: 'partially_released',
              releasedAmount: 25000,
            ),
            milestones: <EscrowMilestoneDto>[
              seedMilestoneDto(id: 'ms-1', status: 'released'),
            ],
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final EscrowDetail detail =
          await repo.releaseMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1');

      expect(detail.escrow.status, 'partially_released');
      expect(detail.escrow.releasedAmount, 25000);
      expect(detail.milestones.single.status, 'released');
      expect(remote.releaseMilestoneCallCount, 1);
      expect(remote.lastMilestoneId, 'ms-1');
    });

    test('refundEscrow re-reads the refunded escrow and forwards the reason',
        () async {
      final remote = FakeEscrowRemoteDataSource(
        writeViaProxy: true,
        details: <String, EscrowDetailDto>{
          'escrow-1': seedDetailDto(
            escrow: seedEscrowDto(
              id: 'escrow-1',
              status: 'refunded',
              refundedAmount: 50000,
            ),
          ),
        },
      );
      final repo = EscrowRepositoryImpl(remote: remote);

      final EscrowDetail detail = await repo.refundEscrow(
        escrowId: 'escrow-1',
        reason: 'goods not delivered',
      );

      expect(detail.escrow.status, 'refunded');
      expect(detail.escrow.refundedAmount, 50000);
      expect(remote.refundCallCount, 1);
      expect(remote.lastRefundReason, 'goods not delivered');
    });
  });
}