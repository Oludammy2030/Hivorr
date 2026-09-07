/// Name-match verification status of an incoming deposit (EP-02-16).
///
/// Mirrors the `name_match_status` check constraint on `financial_deposits`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:326-344`):
/// `pending | matched | mismatched | unverified`. The matching logic is
/// server-side (`financial_deposit_name_match` trigger, exact
/// `lower(btrim(payer_name)) = lower(btrim(legal_name))`); the client only
/// ever *reads* this status through RLS-scoped selects.
enum DepositNameMatchStatus {
  /// No payer name recorded yet (no match run).
  unverified,

  /// Verification is in progress (server-scheduled).
  pending,

  /// Payer name matched the profile legal name.
  matched,

  /// Payer name did not match the profile legal name.
  mismatched;

  /// Parses a persisted `name_match_status` string from the schema.
  static DepositNameMatchStatus fromPersisted(String value) {
    switch (value.toLowerCase()) {
      case 'matched':
        return DepositNameMatchStatus.matched;
      case 'mismatched':
        return DepositNameMatchStatus.mismatched;
      case 'pending':
        return DepositNameMatchStatus.pending;
      default:
        return DepositNameMatchStatus.unverified;
    }
  }

  /// Display label used by [DepositNameMatchIndicator].
  String get displayLabel {
    switch (this) {
      case DepositNameMatchStatus.matched:
        return 'Verified';
      case DepositNameMatchStatus.mismatched:
        return 'Failed';
      case DepositNameMatchStatus.pending:
        return 'Pending';
      case DepositNameMatchStatus.unverified:
        return 'Unverified';
    }
  }
}