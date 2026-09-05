/// A marketplace escrow holding buyer funds until milestone release (EP-02-14).
///
/// Mirrors `financial_escrow`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:191-217`).
/// The client uses the actual frozen migration column set (payer/payee entity
/// ids, financial profile, released/refunded amounts, external reference) —
/// the write paths and display vocabulary follow the server, not a nominal
/// field list (EP-02-14 plan §5.2 deviation documented at §7).
///
/// Pure Dart domain — every mutation is server-authoritative. The client
/// **reads** via `financial_escrow_get` and never writes this table directly
/// (AGENT.md Rule 4); all write actions are staged behind the
/// `escrowWriteViaProxyEnabled` seam.
class Escrow {
  const Escrow({
    required this.id,
    required this.financialProfileId,
    required this.payerEntityId,
    required this.payeeEntityId,
    required this.currencyCode,
    required this.totalAmount,
    required this.releasedAmount,
    required this.refundedAmount,
    required this.status,
    required this.createdAt,
    this.externalReference,
    this.fundedAt,
    this.releasedAt,
    this.refundedAt,
  });

  /// The escrow row id.
  final String id;

  /// The financial profile holding the escrowed funds.
  final String financialProfileId;

  /// The entity paying into the escrow (funds holder).
  final String payerEntityId;

  /// The entity that receives released milestone funds.
  final String payeeEntityId;

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// Total escrow amount.
  final double totalAmount;

  /// Amount already released to the payee.
  final double releasedAmount;

  /// Amount already refunded to the payer.
  final double refundedAmount;

  /// Lifecycle state: `created | funded | partially_released | released |
  /// refunded | cancelled | disputed`.
  final String status;

  /// Optional external reference (e.g. a merchant order id).
  final String? externalReference;

  /// Escrow creation timestamp.
  final DateTime createdAt;

  /// When the escrow was funded, if applicable.
  final DateTime? fundedAt;

  /// When the escrow was fully released, if applicable.
  final DateTime? releasedAt;

  /// When the escrow was refunded, if applicable.
  final DateTime? refundedAt;

  /// Amount still held within the escrow (unreleased and unrefunded).
  double get heldAmount =>
      totalAmount - releasedAmount - refundedAmount;

  /// Whether the escrow is under active dispute (frozen UI state).
  bool get isDisputed => status == 'disputed';

  /// Whether the escrow is still open (unreleased and unrefunded).
  ///
  /// Mirrors the `financial_status_get` `active_escrow_count` semantics —
  /// an escrow is "active" until fully released or refunded/cancelled.
  bool get isActive =>
      status == 'created' ||
      status == 'funded' ||
      status == 'partially_released';
}