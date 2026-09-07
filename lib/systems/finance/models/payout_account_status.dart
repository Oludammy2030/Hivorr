/// Lifecycle status of a bound payout account (EP-02-16).
///
/// Mirrors the `status` check constraint on `financial_payout_accounts`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:262-281`):
/// `pending | active | deactivated`. Ownership verification is the separate
/// `is_verified` flag, not this status.
enum PayoutAccountStatus {
  /// Bound but not yet activated.
  pending,

  /// Activated (paired with `is_verified == true` on the server).
  active,

  /// Deactivated and no longer usable for withdrawals.
  deactivated;

  /// Parses a persisted `status` string from the schema.
  ///
  /// Unknown values map to [PayoutAccountStatus.pending] — a conservative
  /// default that renders the account as unverified-until-proven-otherwise.
  static PayoutAccountStatus fromPersisted(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return PayoutAccountStatus.active;
      case 'deactivated':
        return PayoutAccountStatus.deactivated;
      default:
        return PayoutAccountStatus.pending;
    }
  }

  /// Display label used in the payout account card.
  String get displayLabel {
    switch (this) {
      case PayoutAccountStatus.active:
        return 'Active';
      case PayoutAccountStatus.deactivated:
        return 'Deactivated';
      case PayoutAccountStatus.pending:
        return 'Pending';
    }
  }
}