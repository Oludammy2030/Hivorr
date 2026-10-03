import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/systems/documents/widgets/contract_milestone_adapter.dart';

import '../../support/fakes/fake_service_contract.dart';

void main() {
  group('ContractMilestoneAdapter.toCardMilestones', () {
    test('preserves server sort_order verbatim', () {
      final ServiceContract contract = FakeServiceContractRepository.contract(
        id: 'c1',
      );
      final List<EscrowMilestone> rows =
          ContractMilestoneAdapter.toCardMilestones(contract);
      expect(rows, hasLength(3));
      expect(rows.map((e) => e.milestoneNumber), [1, 2, 3]);
      expect(rows.map((e) => e.sortOrder), [0, 1, 2]);
    });

    test('verified maps to completed-adjacent treatment with caption', () {
      final ServiceContract base = FakeServiceContractRepository.contract(
        id: 'c1',
      );
      final ServiceContract contract = ServiceContract(
        id: base.id,
        serviceListingId: base.serviceListingId,
        clientEntityId: base.clientEntityId,
        professionalEntityId: base.professionalEntityId,
        status: base.status,
        totalAmount: base.totalAmount,
        currencyCode: base.currencyCode,
        milestones: base.milestones
            .map((m) => m.id == 'm1' ? m.copyWithStatus('verified') : m)
            .toList(),
        events: base.events,
      );
      final List<EscrowMilestone> rows =
          ContractMilestoneAdapter.toCardMilestones(contract);
      final EscrowMilestone verified = rows.firstWhere(
        (e) => e.id == 'm1',
      );
      expect(verified.status, 'completed');
      expect(verified.title, contains('(Verified)'));
      expect(
        rows.firstWhere((e) => e.id == 'm2').status,
        'pending',
      );
    });

    test('releasedTotal/progressValue semantics unaffected', () {
      final ServiceContract contract = FakeServiceContractRepository.contract(
        id: 'c1',
      );
      final List<EscrowMilestone> rows =
          ContractMilestoneAdapter.toCardMilestones(contract);
      // All pending → nothing released → progress 0.
      final double released = rows
          .where((e) => e.isReleased)
          .fold(0.0, (a, e) => a + e.amount);
      expect(released, 0);
      expect(contract.totalAmount, 30000);
    });
  });
}
