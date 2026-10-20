// Run: flutter test test/integration/marketplace/milestone_release_ledger_integration_test.dart
//
// EP-03-20 VP6 — Milestone verify→release ledger parity. Composes the REAL
// ContractEscrowOrchestrator (ContractService + EscrowService) over
// FakeServiceContractRepository (seedLinkedContract) + FakeEscrowRepository.
// Fail-closed guardrails: a disputed contract blocks release before any
// escrow write; a disabled Edge proxy write seam blocks before any write.
//
// DV-02 shared ledger fixture: VP11 (earnings_ledger_parity) imports these
// exact values so both tests derive assertions from one seeded definition.

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_state.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';

import '../../support/fakes/fake_contract_escrow.dart';
import '../../support/fakes/fake_service_contract.dart';
import '../../support/fakes/finance/fake_escrow_repository.dart';

// ─── DV-02 shared ledger fixture (imported by VP11) ──────────────────────
/// The single seeded contract total the ledger assertions derive from.
const double ledgerContractTotal = 30000;

/// The single released milestone amount the ledger assertions derive from.
const double ledgerMilestoneAmount = 10000;

/// The ledger currency shared across VP6 + VP11.
const String ledgerCurrency = 'NGN';
// ─────────────────────────────────────────────────────────────────────────

/// Builds the orchestrator over the contract + escrow fakes.
({ContractEscrowOrchestrator orchestrator, FakeEscrowRepository escrows})
_build(ServiceContract contract, {required bool writeAvailable}) {
  final FakeServiceContractRepository contracts = FakeServiceContractRepository(
    seed: <ServiceContract>[contract],
  );
  final FakeEscrowRepository escrows = FakeEscrowRepository(
    writeAvailable: writeAvailable,
  );
  return (
    orchestrator: ContractEscrowOrchestrator(
      contracts: ContractService(repository: contracts),
      escrows: EscrowService(repository: escrows),
      clock: () => DateTime.fromMillisecondsSinceEpoch(9999999999),
    ),
    escrows: escrows,
  );
}

void main() {
  group('EP-03-20 VP6 — milestone verify→release ledger parity', () {
    test('DoD-VP6a: verified linked milestone releases exactly once', () async {
      // Arrange: an active, funded contract with a verified first milestone.
      final ServiceContract contract = seedLinkedContract(
        id: 'c1',
        total: ledgerContractTotal,
        currency: ledgerCurrency,
      );
      final ({
        ContractEscrowOrchestrator orchestrator,
        FakeEscrowRepository escrows,
      })
      built = _build(contract, writeAvailable: true);

      // Act: run the verify-and-release sequence for the verified milestone.
      final ContractEscrowReleaseState state = await built.orchestrator
          .verifyAndReleaseMilestone(contractId: 'c1', milestoneId: 'm1');

      // Assert: funds moved once, the server-authoritative amount equals the
      // ledger fixture (no client arithmetic — read verbatim from the row).
      expect(state.phase, ContractEscrowReleasePhase.released);
      expect(state.ok, isTrue);
      expect(state.releasedAmount, ledgerMilestoneAmount);
      expect(state.code, 'PLT000');
      expect(built.escrows.releaseMilestoneCallCount, 1);
      expect(built.escrows.lastMilestoneId, 'em1');
    });

    test(
      'DoD-VP6b: disputed contract blocks release before any write',
      () async {
        // Arrange: the contract is frozen by a dispute.
        final ServiceContract disputed = seedLinkedContract(
          id: 'c1',
          status: 'disputed',
          total: ledgerContractTotal,
        );
        final ({
          ContractEscrowOrchestrator orchestrator,
          FakeEscrowRepository escrows,
        })
        built = _build(disputed, writeAvailable: true);

        // Act: attempt release on the frozen contract.
        final ContractEscrowReleaseState state = await built.orchestrator
            .verifyAndReleaseMilestone(contractId: 'c1', milestoneId: 'm1');

        // Assert: refused before any escrow write (fail-closed).
        expect(state.phase, ContractEscrowReleasePhase.blocked);
        expect(state.blockReason, ContractEscrowBlockReason.disputed);
        expect(state.ok, isFalse);
        expect(built.escrows.releaseMilestoneCallCount, 0);
        expect(state.code, 'PLT005');
      },
    );

    test(
      'DoD-VP6c: disabled write seam blocks release before any write',
      () async {
        // Arrange: the Edge proxy write seam is off.
        final ServiceContract contract = seedLinkedContract(id: 'c1');
        final ({
          ContractEscrowOrchestrator orchestrator,
          FakeEscrowRepository escrows,
        })
        built = _build(contract, writeAvailable: false);

        // Act: attempt release with the write seam off.
        final ContractEscrowReleaseState state = await built.orchestrator
            .verifyAndReleaseMilestone(contractId: 'c1', milestoneId: 'm1');

        // Assert: refused before any escrow write (no partial state).
        expect(state.phase, ContractEscrowReleasePhase.blocked);
        expect(state.blockReason, ContractEscrowBlockReason.writeUnavailable);
        expect(built.escrows.releaseMilestoneCallCount, 0);
      },
    );

    test('DoD-VP6d: unfunded contract blocks release as not-funded', () async {
      // Arrange: an active contract with no linked escrow.
      final ServiceContract unfunded = seedLinkedContract(
        id: 'c1',
        escrowId: null,
      );
      final ({
        ContractEscrowOrchestrator orchestrator,
        FakeEscrowRepository escrows,
      })
      built = _build(unfunded, writeAvailable: true);

      // Act: attempt release with no escrow linkage.
      final ContractEscrowReleaseState state = await built.orchestrator
          .verifyAndReleaseMilestone(contractId: 'c1', milestoneId: 'm1');

      // Assert: blocked not-funded before any write.
      expect(state.phase, ContractEscrowReleasePhase.blocked);
      expect(state.blockReason, ContractEscrowBlockReason.notFunded);
      expect(built.escrows.releaseMilestoneCallCount, 0);
    });

    test(
      'DoD-VP6e: pending milestone blocks release as not-verified',
      () async {
        // Arrange: an active, funded contract whose first milestone is pending.
        final ServiceContract pending = seedLinkedContract(
          id: 'c1',
          milestones: <ContractMilestone>[
            const ContractMilestone(
              id: 'm1',
              contractId: 'c1',
              escrowMilestoneId: 'em1',
              milestoneNumber: 1,
              title: 'Inspection visit',
              amount: ledgerMilestoneAmount,
              status: 'pending',
              sortOrder: 0,
            ),
          ],
        );
        final ({
          ContractEscrowOrchestrator orchestrator,
          FakeEscrowRepository escrows,
        })
        built = _build(pending, writeAvailable: true);

        // Act: attempt release on a pending milestone.
        final ContractEscrowReleaseState state = await built.orchestrator
            .verifyAndReleaseMilestone(contractId: 'c1', milestoneId: 'm1');

        // Assert: blocked not-verified before any write.
        expect(state.phase, ContractEscrowReleasePhase.blocked);
        expect(state.blockReason, ContractEscrowBlockReason.notVerified);
        expect(built.escrows.releaseMilestoneCallCount, 0);
      },
    );
  });
}
