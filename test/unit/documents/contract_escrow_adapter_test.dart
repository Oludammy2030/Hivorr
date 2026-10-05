import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/systems/documents/widgets/contract_milestone_adapter.dart';

import '../../support/fakes/fake_contract_escrow.dart';
import '../../support/fakes/fake_service_contract.dart';

void main() {
  group('ContractMilestoneAdapter EP-03-11 release display', () {
    test('released renders with Released caption and status', () {
      final ServiceContract base = seedLinkedContract(id: 'c1');
      final ServiceContract contract = ServiceContract(
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
      final List<EscrowMilestone> rows =
          ContractMilestoneAdapter.toCardMilestones(contract);
      final EscrowMilestone released = rows.firstWhere((e) => e.id == 'm1');
      expect(released.status, 'released');
      expect(released.title, contains('(Released)'));
    });

    test('releaseStateFor distinguishes funding/verify/release/dispute', () {
      final ServiceContract linked = seedLinkedContract(id: 'c1');
      final ContractMilestone verified = linked.milestones.firstWhere(
        (m) => m.id == 'm1',
      );
      final ContractMilestone pending = linked.milestones.firstWhere(
        (m) => m.id == 'm2',
      );
      expect(
        ContractMilestoneAdapter.releaseStateFor(linked, verified),
        ContractMilestoneReleaseState.awaitingRelease,
      );
      expect(
        ContractMilestoneAdapter.releaseStateFor(linked, pending),
        ContractMilestoneReleaseState.awaitingVerification,
      );

      final ServiceContract unlinked = FakeServiceContractRepository.contract(
        id: 'c1',
      );
      expect(
        ContractMilestoneAdapter.releaseStateFor(
          unlinked,
          unlinked.milestones.first,
        ),
        ContractMilestoneReleaseState.awaitingFunding,
      );

      final ServiceContract disputed = seedLinkedContract(
        id: 'c1',
        status: 'disputed',
      );
      expect(
        ContractMilestoneAdapter.releaseStateFor(
          disputed,
          disputed.milestones.first,
        ),
        ContractMilestoneReleaseState.disputedBlocked,
      );
    });

    test('releaseStateFor marks past-deadline completed as expired', () {
      final ServiceContract contract = seedLinkedContract(id: 'c1');
      final ContractMilestone expired = seedExpiredMilestone();
      expect(
        ContractMilestoneAdapter.releaseStateFor(
          contract,
          expired,
          now: DateTime.fromMillisecondsSinceEpoch(9999999999),
        ),
        ContractMilestoneReleaseState.expiredAutoRelease,
      );
      final ContractMilestone fresh = seedUnexpiredMilestone();
      expect(
        ContractMilestoneAdapter.releaseStateFor(contract, fresh),
        ContractMilestoneReleaseState.awaitingVerification,
      );
    });

    test('reviewCountdownLabel renders server deadline copy only', () {
      final ContractMilestone expired = seedExpiredMilestone();
      expect(
        ContractMilestoneAdapter.reviewCountdownLabel(
          expired,
          now: DateTime.fromMillisecondsSinceEpoch(9999999999),
        ),
        'Auto-release due',
      );
      final ContractMilestone fresh = seedUnexpiredMilestone(
        expiresAt: DateTime.fromMillisecondsSinceEpoch(2000).add(
          const Duration(days: 3, hours: 4),
        ),
      );
      expect(
        ContractMilestoneAdapter.reviewCountdownLabel(
          fresh,
          now: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
        'Expires in 3d 4h',
      );
      final ServiceContract linked = seedLinkedContract(id: 'c1');
      expect(
        ContractMilestoneAdapter.reviewCountdownLabel(
          linked.milestones.firstWhere((m) => m.id == 'm2'),
        ),
        isNull,
      );
    });
  });
}
