/// A per-currency receiving account attached to a financial profile (EP-02-13).
///
/// Mirrors `financial_currency_accounts` returned as an array within the
/// `financial_profile_get` RPC response
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:89-115`).
/// Pure Dart domain — this task only **displays** account status; binding and
/// activation are server-authoritative via `EP-02-16` (AGENT.md Rule 4).
class CurrencyAccount {
  const CurrencyAccount({
    required this.id,
    required this.financialProfileId,
    required this.entityId,
    required this.currencyCode,
    required this.accountStatus,
    this.receivingAccountNumber,
    this.receivingBankName,
    this.providerReference,
    this.activatedAt,
  });

  /// The account row id.
  final String id;

  /// Owning financial profile id.
  final String financialProfileId;

  /// Owning entity id.
  final String entityId;

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// Account lifecycle status: `pending | active | suspended | closed`.
  final String accountStatus;

  /// Masked receiving account number (available when `active`).
  final String? receivingAccountNumber;

  /// Receiving bank name (available when `active`).
  final String? receivingBankName;

  /// Payment provider reference (e.g. Paystack sub-account id).
  final String? providerReference;

  /// When the account was activated, if applicable.
  final DateTime? activatedAt;

  /// Whether the account is ready to receive payments.
  bool get isActive => accountStatus == 'active';

  /// Whether the account is awaiting activation.
  bool get isPending => accountStatus == 'pending';
}
