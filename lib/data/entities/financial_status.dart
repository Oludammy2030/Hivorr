import 'package:hivorr/data/entities/balance.dart';

/// Aggregated financial status combining profile, balances, and limits (EP-02-13).
///
/// Mirrors the `financial_status_get` RPC response
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1566-1618`).
/// Pure Dart domain — read-only aggregate consumed by the financial dashboard.
class FinancialStatus {
  const FinancialStatus({
    required this.defaultCurrency,
    required this.profileStatus,
    required this.balances,
    required this.activeEscrowCount,
    required this.cashoutLimit,
  });

  /// The entity's default currency code.
  final String defaultCurrency;

  /// The financial profile lifecycle status.
  final String profileStatus;

  /// Per-currency balance entries.
  final List<Balance> balances;

  /// Number of currently active (unreleased) escrow entries.
  final int activeEscrowCount;

  /// KYC-derived maximum cashout limit.
  final double cashoutLimit;

  /// Whether the profile is in an operational state.
  bool get isActive => profileStatus == 'active';
}
