import 'package:hivorr/data/models/balance_dto.dart';

/// Data Transfer Object for the aggregated financial status (EP-02-13).
///
/// Mirrors the `financial_status_get` RPC envelope `data` object
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1566-1618`).
/// Combines profile status, per-currency balances, escrow count, and limits
/// in a single RPC call.
class FinancialStatusDto {
  const FinancialStatusDto({
    required this.defaultCurrency,
    required this.profileStatus,
    required this.balances,
    required this.activeEscrowCount,
    required this.cashoutLimit,
  });

  factory FinancialStatusDto.fromJson(Map<String, dynamic> json) =>
      FinancialStatusDto(
        defaultCurrency: (json['default_currency'] as String?) ?? 'NGN',
        profileStatus: (json['profile_status'] as String?) ?? 'active',
        balances: _parseBalances(json['balances']),
        activeEscrowCount: _toInt(json['active_escrow_count']),
        cashoutLimit: _toDouble(json['cashout_limit']),
      );

  final String defaultCurrency;
  final String profileStatus;
  final List<BalanceDto> balances;
  final int activeEscrowCount;
  final double cashoutLimit;

  static List<BalanceDto> _parseBalances(dynamic value) {
    if (value is! List) return const <BalanceDto>[];
    return value
        .map((e) => BalanceDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
