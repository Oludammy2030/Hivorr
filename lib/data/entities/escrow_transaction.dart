/// An escrow-scoped ledger summary entry (EP-02-14).
///
/// Rendered from the `financial_escrow_get` envelope transactions list
/// (fund / release / refund entries). The frozen EP-02-04 read model does not
/// currently return a transactions array, so consumers receive an empty list
/// and render a graceful summary; the full double-entry ledger stays
/// server-side (`financial_transactions`, AGENT.md Rule 4).
class EscrowTransaction {
  const EscrowTransaction({
    required this.id,
    required this.escrowId,
    required this.type,
    required this.amount,
    required this.direction,
    required this.entityId,
    required this.reference,
    required this.createdAt,
  });

  /// Transaction row id.
  final String id;

  /// Owning escrow id.
  final String escrowId;

  /// Event type: `fund | release | refund | fee | chargeback`.
  final String type;

  /// Absolute transaction amount.
  final double amount;

  /// Cash-flow direction: `in` or `out` relative to the escrow.
  final String direction;

  /// The counterparty entity id.
  final String entityId;

  /// Server-side transaction reference.
  final String reference;

  /// Transaction timestamp.
  final DateTime createdAt;

  /// Whether the cash flows into the escrow (fund).
  bool get isInbound => direction == 'in';

  /// Whether the cash flows out of the escrow (release/refund).
  bool get isOutbound => direction == 'out';
}