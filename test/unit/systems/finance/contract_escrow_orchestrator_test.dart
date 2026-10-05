import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_state.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';

import '../../../support/fakes/fake_contract_escrow.dart';
import '../../../support/fakes/fake_service_contract.dart';
import '../../../support/fakes/finance/fake_escrow_repository.dart';

void main() {
  ContractEscrowOrchestrator orchestrator({
    ServiceContract? contract,
    bool writeAvailable = true,
  }) {
    final FakeServiceContractRepository contracts =
        FakeServiceContractRepository(
      seed: <ServiceContract>[contract ?? seedLinkedContract()],
    );
    final FakeEscrowRepository escrows = FakeEscrowRepository(
      writeAvailable: writeAvailable,
    );
    return ContractEscrowOrchestrator(
      contracts: ContractService(repository: contracts),
      escrows: EscrowService(repository: escrows),
      clock: () => DateTime.fromMillisecondsSinceEpoch(9999999999),
    );
  }

  group('ContractEscrowOrchestrator pre-flight', () {
    test('unlinked contract is blocked not-funded', () async {
      final ServiceContract unlinked = seedLinkedContract(
        id: 'c1',
        escrowId: null,
      );
      // Strip escrow milestone links to mirror the unfunded shape.
      final ServiceContract shaped = ServiceContract(
        id: unlinked.id,
        serviceListingId: unlinked.serviceListingId,
        clientEntityId: unlinked.clientEntityId,
        professionalEntityId: unlinked.professionalEntityId,
        status: unlinked.status,
        totalAmount: unlinked.totalAmount,
        currencyCode: unlinked.currencyCode,
        milestones: unlinked.milestones
            .map(
              (ContractMilestone m) => ContractMilestone(
                id: m.id,
                contractId: m.contractId,
                milestoneNumber: m.milestoneNumber,
                title: m.title,
                amount: m.amount,
                status: m.status,
                sortOrder: m.sortOrder,
              ),
            )
            .toList(),
        events: unlinked.events,
      );
      final ContractEscrowReleaseState state = await orchestrator(
        contract: shaped,
      ).checkReleaseState(contractId: 'c1', milestoneId: 'm1');
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(
        state.blockReason,
        ContractEscrowBlockReason.notFunded,
      );
      expect(state.code, 'PLT005');
    });

    test('pending milestone is blocked not-verified', () async {
      final ContractEscrowReleaseState state = await orchestrator().checkReleaseState(
        contractId: 'c1',
        milestoneId: 'm2',
      );
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(state.blockReason, ContractEscrowBlockReason.notVerified);
    });

    test('verified milestone is releasable when seam is on', () async {
      final ContractEscrowReleaseState state = await orchestrator().checkReleaseState(
        contractId: 'c1',
        milestoneId: 'm1',
      );
      expect(state.phase, ContractEscrowReleasePhase.idle);
      expect(state.escrowId, 'escrow-1');
      expect(state.escrowMilestoneId, 'em1');
    });

    test('verified milestone is blocked write-unavailable when seam is off',
        () async {
      final ContractEscrowReleaseState state =
          await orchestrator(writeAvailable: false).checkReleaseState(
        contractId: 'c1',
        milestoneId: 'm1',
      );
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(
        state.blockReason,
        ContractEscrowBlockReason.writeUnavailable,
      );
      expect(state.code, 'PLT002');
    });

    test('disputed contract blocks before fund movement', () async {
      final ContractEscrowReleaseState state =
          await orchestrator(
            contract: seedLinkedContract(id: 'c1', status: 'disputed'),
          ).checkReleaseState(contractId: 'c1', milestoneId: 'm1');
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(state.blockReason, ContractEscrowBlockReason.disputed);
    });

    test('already-released milestone is a blocked no-op', () async {
      final ServiceContract base = seedLinkedContract(id: 'c1');
      final ServiceContract released = ServiceContract(
        id: base.id,
        serviceListingId: base.serviceListingId,
        clientEntityId: base.clientEntityId,
        professionalEntityId: base.professionalEntityId,
        status: base.status,
        escrowId: base.escrowId,
        totalAmount: base.totalAmount,
        currencyCode: base.currencyCode,
        milestones: base.milestones
            .map(
              (ContractMilestone m) => m.id == 'm1'
                  ? m.copyWithStatus('released')
                  : m,
            )
            .toList(),
        events: base.events,
      );
      final ContractEscrowReleaseState state =
          await orchestrator(contract: released).checkReleaseState(
        contractId: 'c1',
        milestoneId: 'm1',
      );
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(
        state.blockReason,
        ContractEscrowBlockReason.alreadyReleased,
      );
    });

    test('idempotency keys are unique v4', () {
      final ContractEscrowOrchestrator o = orchestrator();
      expect(
        o.newIdempotencyKey() == o.newIdempotencyKey(),
        isFalse,
      );
    });
  });
}
