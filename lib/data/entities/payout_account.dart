import 'package:hivorr/systems/finance/models/payout_account_status.dart';

/// A bank account bound by the entity for payouts (EP-02-16).
///
/// Mirrors `financial_payout_accounts`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:262-281`).
/// Binding is server-authoritative via `financial_payout_account_bind`; the
/// client keeps a display mirror of successfully bound accounts because the
/// authenticated role has **no** SELECT grant on this table (see migration
/// §17 grants) — the only client read surface is the local store populated
/// by each successful bind.
class PayoutAccount {
  const PayoutAccount({
    required this.id,
    required this.currencyCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.status,
    this.isVerified = false,
    this.isDefault = false,
    this.verificationMethod,
    this.verifiedAt,
    this.createdAt,
  });

  /// Server-assigned `financial_payout_accounts.id`.
  final String id;

  /// ISO 4217 currency code (`char(3)`).
  final String currencyCode;

  /// Bound bank name (display-only; never logged raw).
  final String bankName;

  /// Raw account number (display-masked; never logged raw).
  final String accountNumber;

  /// Bound account holder name (display-masked; never logged raw).
  final String accountName;

  /// Lifecycle status.
  final PayoutAccountStatus status;

  /// Whether ownership verification completed on the server
  /// (`financial_payout_account_verify`, service-role only).
  final bool isVerified;

  /// Whether this is the entity's default payout account.
  final bool isDefault;

  /// Server-recognized verification method (when verified).
  final String? verificationMethod;

  /// When the account was verified.
  final DateTime? verifiedAt;

  /// Account creation time (bound time on the client mirror).
  final DateTime? createdAt;

  /// Whether the account is usable for withdrawals (mirrors the server's
  /// `is_verified` gate in `financial_withdraw`).
  bool get isUsable => isVerified && status == PayoutAccountStatus.active;

  /// Last four digits of the account number for display.
  String get maskedAccountNumber {
    final String raw = accountNumber.trim();
    if (raw.length <= 4) return '****';
    return '***${raw.substring(raw.length - 4)}';
  }
}