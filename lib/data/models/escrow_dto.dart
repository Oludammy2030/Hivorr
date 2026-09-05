/// Data Transfer Object for the escrow header read model (EP-02-14).
///
/// Mirrors a `financial_escrow` row returned within the `financial_escrow_get`
/// envelope (`supabase/migrations/20260829100004_financial_integrity_schema.sql:191-217`).
/// Uses the actual frozen migration column set — `financial_profile_id`,
/// `payer_entity_id`, `payee_entity_id`, `released_amount`, `refunded_amount`,
/// `external_reference` (EP-02-14 plan §3 nominal list deviation documented).
class EscrowDto {
  const EscrowDto({
    required this.id,
    required this.financialProfileId,
    required this.payerEntityId,
    required this.payeeEntityId,
    required this.currencyCode,
    required this.totalAmount,
    required this.releasedAmount,
    required this.refundedAmount,
    required this.status,
    required this.createdAt,
    this.externalReference,
    this.fundedAt,
    this.releasedAt,
    this.refundedAt,
  });

  factory EscrowDto.fromJson(Map<String, dynamic> json) => EscrowDto(
        id: (json['id'] as String?) ?? '',
        financialProfileId: (json['financial_profile_id'] as String?) ?? '',
        payerEntityId: (json['payer_entity_id'] as String?) ?? '',
        payeeEntityId: (json['payee_entity_id'] as String?) ?? '',
        currencyCode: (json['currency_code'] as String?) ?? '',
        totalAmount: _toDouble(json['total_amount']),
        releasedAmount: _toDouble(json['released_amount']),
        refundedAmount: _toDouble(json['refunded_amount']),
        status: (json['status'] as String?) ?? 'created',
        createdAt: _parseDateTime(json['created_at']),
        externalReference: json['external_reference'] as String?,
        fundedAt: _parseNullableDateTime(json['funded_at']),
        releasedAt: _parseNullableDateTime(json['released_at']),
        refundedAt: _parseNullableDateTime(json['refunded_at']),
      );

  final String id;
  final String financialProfileId;
  final String payerEntityId;
  final String payeeEntityId;
  final String currencyCode;
  final double totalAmount;
  final double releasedAmount;
  final double refundedAmount;
  final String status;
  final DateTime createdAt;
  final String? externalReference;
  final DateTime? fundedAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;

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

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}