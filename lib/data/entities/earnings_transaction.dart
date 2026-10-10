/// A single server-projected ledger row for the earnings history (EP-03-16).
///
/// Mirrors one `items[]` element of the `service_transaction_history` RPC
/// `data` object
/// (`supabase/migrations/20261008090001_service_earnings_visibility.sql`).
/// Pure Dart domain — `direction` and all attribution are server-computed;
/// the client renders rows verbatim in server order and never re-sorts or
/// re-aggregates for settlement (AGENT.md Rule 4).
class EarningsTransaction {
  const EarningsTransaction({
    required this.id,
    required this.type,
    required this.currencyCode,
    required this.amount,
    required this.direction,
    this.sourceEntityId,
    this.destinationEntityId,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.createdAt,
    this.contractId,
    this.contractStatus,
    this.escrowStatus,
  });

  /// Ledger row id.
  final String id;

  /// Ledger event type (`escrow_fund`, `escrow_release`, `escrow_refund`,
  /// `deposit`, `withdrawal`, `conversion_debit`, `conversion_credit`,
  /// `fee`, `adjustment`).
  final String type;

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// Absolute transaction amount (display-only).
  final double amount;

  /// Cash-flow direction relative to the caller: `in`, `out`, or `self`
  /// (self-moves such as available-to-held funding).
  final String direction;

  /// Ledger source entity id, if any.
  final String? sourceEntityId;

  /// Ledger destination entity id, if any.
  final String? destinationEntityId;

  /// Ledger reference type (`escrow`, `payout`, `deposit`, `conversion`,
  /// `system`), if any.
  final String? referenceType;

  /// Ledger reference id, if any.
  final String? referenceId;

  /// Server-side description, if any.
  final String? description;

  /// Transaction timestamp.
  final DateTime createdAt;

  /// Attributed contract id via `service_contracts.escrow_id`, if any.
  final String? contractId;

  /// Attributed contract status, if any.
  final String? contractStatus;

  /// Attributed escrow status, if any.
  final String? escrowStatus;

  /// Whether value flows toward the caller.
  bool get isInbound => direction == 'in';

  /// Whether value flows away from the caller.
  bool get isOutbound => direction == 'out';

  /// Whether the backing escrow is frozen in dispute.
  bool get isDisputed => escrowStatus == 'disputed';

  /// Whether the row is an earned release for the caller.
  bool get isEarnedRelease => type == 'escrow_release' && isInbound;
}

/// A keyset-paginated history page (EP-03-16).
///
/// Cursor shape mirrors the RPC `{created_at, id}` keyset; server order is
/// authoritative and preserved verbatim.
class EarningsTransactionPage {
  const EarningsTransactionPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  /// Rows in server order (newest first).
  final List<EarningsTransaction> items;

  /// Whether another page exists.
  final bool hasMore;

  /// Opaque cursor for the next page (`null` when [hasMore] is false).
  final Map<String, dynamic>? nextCursor;

  /// Whether the page holds no rows (drives `HivorrEmptyState`).
  bool get isEmpty => items.isEmpty;
}
