import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';

/// Adapter: contract milestones → `MilestoneListCard` view props (EP-03-10).
///
/// Preserves server (`sort_order`, then `milestone_number`) order verbatim and
/// maps `verified` to the card's completed-adjacent treatment with an explicit
/// `(Verified)` title suffix (the card vocabulary is
/// `pending | completed | released`; no card fork). Pure function — covered by
/// `milestone_list_card_adapter_test`.
abstract final class ContractMilestoneAdapter {
  /// Maps [contract]'s milestones to card rows in server order.
  static List<EscrowMilestone> toCardMilestones(ServiceContract contract) {
    final List<ContractMilestone> sorted = <ContractMilestone>[
      ...contract.milestones,
    ]..sort(
      (ContractMilestone a, ContractMilestone b) =>
          a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.milestoneNumber.compareTo(b.milestoneNumber),
    );
    return sorted
        .map(
          (ContractMilestone m) => EscrowMilestone(
            id: m.id,
            escrowId: contract.escrowId ?? contract.id,
            milestoneNumber: m.milestoneNumber,
            title: m.isVerified ? '${m.title} (Verified)' : m.title,
            description: m.description,
            amount: m.amount,
            status: m.isVerified ? 'completed' : m.status,
            sortOrder: m.sortOrder,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            completedAt: m.completedAt,
            releasedAt: m.releasedAt,
          ),
        )
        .toList(growable: false);
  }
}
