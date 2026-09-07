/// Result of a successful withdrawal (EP-02-16).
///
/// Mirrors the `financial_withdraw` RPC response `data` object
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1322-1328`).
class WithdrawalResult {
  const WithdrawalResult({
    required this.payoutId,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.cashoutRemaining,
  });

  /// `financial_payouts.id` created by the server.
  final String payoutId;

  /// Gross withdrawal amount (major units).
  final double amount;

  /// Fee applied by the server.
  final double fee;

  /// Amount net of fees.
  final double netAmount;

  /// Remaining cashout limit after this withdrawal.
  final double cashoutRemaining;
}