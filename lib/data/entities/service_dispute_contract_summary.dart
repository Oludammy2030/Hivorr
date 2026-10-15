/// Read-only summary of the service engagement anchoring a dispute (EP-03-17).
///
/// Corresponds to the `contract` object joined inside the
/// `service_dispute_get` envelope
/// (`supabase/migrations/20261011090001_service_dispute_contract_link.sql`
/// §5): the authoritative `service_contracts` row plus the listing title.
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class ServiceDisputeContractSummary {
  const ServiceDisputeContractSummary({
    required this.id,
    required this.status,
    this.escrowId,
    required this.totalAmount,
    required this.currencyCode,
    required this.serviceListingId,
    this.listingTitle,
  });

  /// The `service_contracts.id` anchoring the dispute.
  final String id;

  /// Lifecycle state (`offered|active|completed|disputed|closed|cancelled`).
  final String status;

  /// Linked `financial_escrow.id`, `null` while the contract is unfunded.
  final String? escrowId;

  /// Contract total (server-computed, never client-summed).
  final double totalAmount;

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// The bound `service_listings` row.
  final String serviceListingId;

  /// Denormalized listing title for display (`null` when unavailable).
  final String? listingTitle;

  /// Whether the contract is frozen pending dispute resolution.
  bool get isDisputed => status == 'disputed';

  /// Whether an escrow hold backs this engagement.
  bool get isFunded => escrowId != null && escrowId!.trim().isNotEmpty;
}
