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
            title: _cardTitle(m),
            description: m.description,
            amount: m.amount,
            status: _cardStatus(m),
            sortOrder: m.sortOrder,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            completedAt: m.completedAt,
            releasedAt: m.releasedAt,
          ),
        )
        .toList(growable: false);
  }

  /// Card title with explicit verification/release captions (no card fork).
  static String _cardTitle(ContractMilestone m) {
    if (m.isReleased) return '${m.title} (Released)';
    if (m.isVerified) return '${m.title} (Verified)';
    return m.title;
  }

  /// Card status mapping: `verified` renders with the completed-adjacent
  /// treatment; `released` passes through to the card's released treatment.
  static String _cardStatus(ContractMilestone m) {
    if (m.isVerified) return 'completed';
    return m.status;
  }

  /// Release phase for one milestone, derived from server state only.
  ///
  /// Used by the EP-03-11 escrow section for per-row copy. `expired` here
  /// means the server deadline passed (auto-release sweep owns the release);
  /// the client never releases on this signal.
  static ContractMilestoneReleaseState releaseStateFor(
    ServiceContract contract,
    ContractMilestone m, {
    DateTime? now,
  }) {
    final DateTime clock = now ?? DateTime.now();
    if (contract.isDisputed) {
      return ContractMilestoneReleaseState.disputedBlocked;
    }
    if (m.isReleased) return ContractMilestoneReleaseState.released;
    if (contract.escrowId == null || m.escrowMilestoneId == null) {
      return ContractMilestoneReleaseState.awaitingFunding;
    }
    if (m.isVerified) return ContractMilestoneReleaseState.awaitingRelease;
    if (m.isCompleted) {
      final DateTime? expires = m.reviewPeriodExpiresAt;
      if (expires != null && !clock.isBefore(expires)) {
        return ContractMilestoneReleaseState.expiredAutoRelease;
      }
      return ContractMilestoneReleaseState.awaitingVerification;
    }
    if (m.isPending) return ContractMilestoneReleaseState.awaitingVerification;
    return ContractMilestoneReleaseState.awaitingVerification;
  }

  /// Human-readable countdown from the server deadline, or `null` when none.
  ///
  /// Examples: `Expires in 3d 4h`, `Expires in 5h 12m`, `Auto-release due`.
  /// Returns `null` for pending/verified/released rows and when the server
  /// has not set a deadline. Pure formatting — never a release trigger.
  static String? reviewCountdownLabel(
    ContractMilestone m, {
    DateTime? now,
  }) {
    if (!m.isCompleted) return null;
    final DateTime? expires = m.reviewPeriodExpiresAt;
    if (expires == null) return null;
    final DateTime clock = now ?? DateTime.now();
    if (!clock.isBefore(expires)) return 'Auto-release due';
    final Duration remaining = expires.difference(clock);
    if (remaining.inDays >= 1) {
      final int hours = remaining.inHours % 24;
      return 'Expires in ${remaining.inDays}d ${hours}h';
    }
    if (remaining.inHours >= 1) {
      return 'Expires in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
    return 'Expires in ${remaining.inMinutes}m';
  }
}

/// Display-only release phase for a contract milestone (EP-03-11).
enum ContractMilestoneReleaseState {
  /// No linked escrow yet (funding pending).
  awaitingFunding,

  /// Work delivered, awaiting client verification.
  awaitingVerification,

  /// Verified, awaiting platform release.
  awaitingRelease,

  /// Deadline passed; the cron sweep owns the release.
  expiredAutoRelease,

  /// Funds moved (`released_at` set server-side).
  released,

  /// Contract frozen pending dispute resolution.
  disputedBlocked,
}
