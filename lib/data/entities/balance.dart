/// Per-currency balance for an entity's financial profile (EP-02-13).
///
/// Mirrors `financial_balances` / `financial_balance_get` RPC read model
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:120-146`).
/// Pure Dart domain — all balance mutations are server-authoritative via
/// `EP-02-14/16` RPCs; the client never writes `financial_balances`
/// directly (AGENT.md Rule 4).
class Balance {
  const Balance({
    required this.currencyCode,
    required this.availableBalance,
    required this.heldBalance,
    required this.pendingBalance,
    required this.totalDeposited,
    required this.totalWithdrawn,
    this.lastTransactionAt,
  });

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// Available for immediate use (withdrawal / payment).
  final double availableBalance;

  /// Held by escrow or pending resolution.
  final double heldBalance;

  /// Pending deposit confirmation.
  final double pendingBalance;

  /// Lifetime deposited amount.
  final double totalDeposited;

  /// Lifetime withdrawn amount.
  final double totalWithdrawn;

  /// Timestamp of the most recent transaction affecting this balance.
  final DateTime? lastTransactionAt;

  /// The sum of all balance components.
  double get totalBalance => availableBalance + heldBalance + pendingBalance;

  /// Whether any balance component is non-zero.
  bool get hasBalance =>
      availableBalance > 0 || heldBalance > 0 || pendingBalance > 0;
}
