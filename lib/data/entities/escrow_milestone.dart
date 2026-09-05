/// A milestone-based release condition attached to an escrow (EP-02-14).
///
/// Mirrors `financial_escrow_milestones`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:232-257`).
/// Pure Dart domain — milestone state is server-authoritative
/// (`financial_escrow_milestone_complete`, AGENT.md Rule 4); the client only
/// renders status and pre-validates the `sum(milestones) == total` invariant
/// before create.
class EscrowMilestone {
  const EscrowMilestone({
    required this.id,
    required this.escrowId,
    required this.milestoneNumber,
    required this.title,
    required this.amount,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    this.description,
    this.completedAt,
    this.releasedAt,
  });

  /// The milestone row id.
  final String id;

  /// Owning escrow id.
  final String escrowId;

  /// 1-based milestone position within the escrow.
  final int milestoneNumber;

  /// Milestone title (1–255 chars server-side).
  final String title;

  /// Optional milestone description.
  final String? description;

  /// Milestone amount.
  final double amount;

  /// Lifecycle state: `pending | completed | released`.
  final String status;

  /// Display ordering within the escrow.
  final int sortOrder;

  /// Milestone creation timestamp.
  final DateTime createdAt;

  /// When the milestone was marked complete, if applicable.
  final DateTime? completedAt;

  /// When the milestone's funds were released, if applicable.
  final DateTime? releasedAt;

  /// Whether the milestone has been delivered (completed).
  bool get isCompleted => status == 'completed';

  /// Whether the milestone's funds have been released.
  bool get isReleased => status == 'released';

  /// Whether the milestone is awaiting delivery.
  bool get isPending => status == 'pending';
}