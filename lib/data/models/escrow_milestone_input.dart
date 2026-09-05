/// Value object describing a milestone in an escrow create request (EP-02-14).
///
/// Serializes to the `jsonb` milestone array consumed by
/// `financial_escrow_create`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:815-827`,
/// keys: `milestone_number`, `title`, `description`, `amount`, `sort_order`).
class EscrowMilestoneInput {
  const EscrowMilestoneInput({
    required this.milestoneNumber,
    required this.title,
    required this.amount,
    this.description,
    this.sortOrder,
  });

  /// 1-based milestone position.
  final int milestoneNumber;

  /// Milestone title (1–255 chars).
  final String title;

  /// Milestone amount.
  final double amount;

  /// Optional description.
  final String? description;

  /// Display ordering; falls back to [milestoneNumber] when absent.
  final int? sortOrder;

  /// The JSON payload fragment sent through the write seam / proxy.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'milestone_number': milestoneNumber,
        'title': title,
        'description': description,
        'amount': amount,
        'sort_order': sortOrder ?? milestoneNumber,
      };
}