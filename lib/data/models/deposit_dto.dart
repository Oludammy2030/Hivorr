/// Transport DTO for a `financial_deposits` row (EP-02-16).
///
/// Mirrors the RLS-scoped REST select of `financial_deposits`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:326-344`).
class DepositDto {
  const DepositDto({
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

  /// Parses a `financial_deposits` REST row.
  static DepositDto fromJson(Map<String, dynamic> json) => DepositDto(
        id: (json['id'] as String?) ?? '',
        currencyCode: (json['currency_code'] as String?) ?? '',
        amount: _toDouble(json['amount']),
        nameMatchStatus: (json['name_match_status'] as String?) ?? 'unverified',
        payerName: json['payer_name'] as String?,
        nameMatchScore: _toNullableDouble(json['name_match_score']),
        externalReference: json['external_reference'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        creditedAt: _toNullableDateTime(json['credited_at']),
        createdAt: _toNullableDateTime(json['created_at']),
      );

  final String id;
  final String currencyCode;
  final double amount;
  final String nameMatchStatus;
  final String? payerName;
  final double? nameMatchScore;
  final String? externalReference;
  final String status;
  final DateTime? creditedAt;
  final DateTime? createdAt;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}