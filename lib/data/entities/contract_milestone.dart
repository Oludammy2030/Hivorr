/// A milestone-based work split attached to a service contract (EP-03-10).
///
/// Mirrors `contract_milestones`
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`).
/// Pure Dart domain — milestone state is server-authoritative
/// (`service_contract_complete_milestone` / `service_contract_verify_milestone`,
/// `AGENT.md` Rule 4); the client only renders status and pre-validates the
/// `sum(milestones) == total` invariant before offer.
class ContractMilestone {
  const ContractMilestone({
    required this.id,
    required this.contractId,
    this.escrowMilestoneId,
    required this.milestoneNumber,
    required this.title,
    this.description,
    required this.amount,
    required this.status,
    this.evidencePath,
    required this.sortOrder,
    this.completedAt,
    this.verifiedAt,
    this.releasedAt,
    this.reviewPeriodExpiresAt,
  });

  /// The milestone row id.
  final String id;

  /// Owning contract id.
  final String contractId;

  /// Future link to `financial_escrow_milestones` (`null` until EP-03-11).
  final String? escrowMilestoneId;

  /// 1-based milestone position within the contract.
  final int milestoneNumber;

  /// Milestone title (1–255 chars server-side).
  final String title;

  /// Optional milestone description (≤2000 chars server-side).
  final String? description;

  /// Milestone amount.
  final double amount;

  /// Lifecycle state: `pending | completed | verified | released`.
  final String status;

  /// Evidence storage path (`service-listing-media/{professional_id}/…`).
  final String? evidencePath;

  /// Display ordering within the contract.
  final int sortOrder;

  /// When the milestone was marked complete, if applicable.
  final DateTime? completedAt;

  /// When the milestone was verified by the client, if applicable.
  final DateTime? verifiedAt;

  /// When the milestone's funds were released, if applicable (EP-03-11).
  final DateTime? releasedAt;

  /// Server-clock review deadline (`completed_at + 7 days`, EP-03-11).
  ///
  /// Set by the `contract_milestones_set_review_expiry` trigger on
  /// pending->completed; cleared on revision->pending. `null` means no expiry
  /// (pending, historical, or already released rows). Countdowns render from
  /// this value only — the client never computes release timing.
  final DateTime? reviewPeriodExpiresAt;

  /// Whether the milestone is awaiting delivery.
  bool get isPending => status == 'pending';

  /// Whether the professional marked the milestone delivered.
  bool get isCompleted => status == 'completed';

  /// Whether the client accepted the milestone.
  bool get isVerified => status == 'verified';

  /// Whether the milestone's funds were released.
  bool get isReleased => status == 'released';

  /// Copies this milestone with a new [status] (memoized-list sync helper).
  ContractMilestone copyWithStatus(String status) => ContractMilestone(
    id: id,
    contractId: contractId,
    escrowMilestoneId: escrowMilestoneId,
    milestoneNumber: milestoneNumber,
    title: title,
    description: description,
    amount: amount,
    status: status,
    evidencePath: evidencePath,
    sortOrder: sortOrder,
    completedAt: completedAt,
    verifiedAt: verifiedAt,
    releasedAt: releasedAt,
    reviewPeriodExpiresAt: reviewPeriodExpiresAt,
  );
}
