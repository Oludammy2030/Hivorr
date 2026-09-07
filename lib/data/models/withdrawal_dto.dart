/// Transport DTO for the `financial_withdraw` RPC response `data` (EP-02-16).
///
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1322-1328`):
/// `{payout_id, amount, fee, net_amount, cashout_remaining}`.
class WithdrawalDto {
  const WithdrawalDto({
    required this.payoutId,
    required this.amount,
    required this.fee,
    required this.netAmount,
    required this.cashoutRemaining,
  });

  /// Parses the withdraw RPC `data` object.
  static WithdrawalDto fromJson(Map<String, dynamic> json) => WithdrawalDto(
        payoutId: (json['payout_id'] as String?) ?? '',
        amount: _toDouble(json['amount']),
        fee: _toDouble(json['fee']),
        netAmount: _toDouble(json['net_amount']),
        cashoutRemaining: _toDouble(json['cashout_remaining']),
      );

  final String payoutId;
  final double amount;
  final double fee;
  final double netAmount;
  final double cashoutRemaining;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}