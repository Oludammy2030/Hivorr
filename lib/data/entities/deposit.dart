import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

/// An incoming deposit (EP-02-16).
///
/// Mirrors `financial_deposits`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:326-344`).
/// Deposits are recorded and name-verified server-side
/// (`financial_deposit_record` / `financial_deposit_verify_name`, both
/// service-role only); the client only ever *reads* them through the
/// RLS-scoped REST select grant (§17 lines 1680-1698 / line 555).
class Deposit {
  const Deposit({
    required this.id,
    required this.currencyCode,
    required this.amount,
    required this.nameMatchStatus,
    this.payerName,
    this.nameMatchScore,
    this.externalReference,
    this.status = 'pending',
    this.creditedAt,
    this.createdAt,
  });

  /// `financial_deposits.id`.
  final String id;

  /// ISO 4217 currency code (`char(3)`).
  final String currencyCode;

  /// Deposit amount in major units (`numeric`, double representation).
  final double amount;

  /// Names the payer provided (display-purpose only; never logged raw).
  final String? payerName;

  /// Server-computed name-match status.
  final DepositNameMatchStatus nameMatchStatus;

  /// Server-computed match confidence in `[0.0, 1.0]` when available.
  final double? nameMatchScore;

  /// Optional external reference (e.g. gateway transfer reference).
  final String? externalReference;

  /// Deposit lifecycle status (`pending | credited | flagged | reversed`).
  final String status;

  /// When the deposit was credited to the balance.
  final DateTime? creditedAt;

  /// When the deposit row was created.
  final DateTime? createdAt;

  /// Whether the balance was credited (mirrors `status == 'credited'`).
  bool get isCredited => status == 'credited';
}