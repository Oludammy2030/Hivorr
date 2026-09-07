/// Transport DTO for the `financial_payout_account_bind` RPC response `data`
/// (EP-02-16).
///
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1196-1199`):
/// `{payout_account_id, currency_code, status}`.
class PayoutBindDto {
  const PayoutBindDto({
    required this.payoutAccountId,
    required this.currencyCode,
    required this.status,
  });

  /// Parses the bind RPC `data` object.
  static PayoutBindDto fromJson(Map<String, dynamic> json) => PayoutBindDto(
        payoutAccountId: (json['payout_account_id'] as String?) ?? '',
        currencyCode: (json['currency_code'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
      );

  final String payoutAccountId;
  final String currencyCode;
  final String status;
}