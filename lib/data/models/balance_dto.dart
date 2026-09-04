/// Data Transfer Object for the balance read model (EP-02-13).
///
/// Mirrors the `financial_balance_get` RPC envelope `data` object
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:717-754`).
/// When no row exists, the RPC defaults to zero balances.
class BalanceDto {
  const BalanceDto({
    required this.currencyCode,
    required this.availableBalance,
    required this.heldBalance,
    required this.pendingBalance,
    required this.totalDeposited,
    required this.totalWithdrawn,
    this.lastTransactionAt,
  });

  factory BalanceDto.fromJson(Map<String, dynamic> json) => BalanceDto(
        currencyCode: (json['currency_code'] as String?) ?? '',
        availableBalance: _toDouble(json['available_balance']),
        heldBalance: _toDouble(json['held_balance']),
        pendingBalance: _toDouble(json['pending_balance']),
        totalDeposited: _toDouble(json['total_deposited']),
        totalWithdrawn: _toDouble(json['total_withdrawn']),
        lastTransactionAt: json['last_transaction_at'] != null
            ? _parseDateTime(json['last_transaction_at'])
            : null,
      );

  final String currencyCode;
  final double availableBalance;
  final double heldBalance;
  final double pendingBalance;
  final double totalDeposited;
  final double totalWithdrawn;
  final DateTime? lastTransactionAt;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
