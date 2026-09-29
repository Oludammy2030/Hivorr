/// Data Transfer Object for a `job_quotations` row (EP-04-02).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260928090002_quotations_hires_schema.sql:41-82`),
/// using the actual snake_case keys returned inside the `quotation_*`
/// envelopes.
class JobQuotationDto {
  const JobQuotationDto({
    required this.id,
    required this.applicationId,
    required this.proposedBy,
    required this.proposedAmount,
    required this.currencyCode,
    this.durationDays,
    this.message,
    required this.revisionNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.decidedAt,
  });

  factory JobQuotationDto.fromJson(Map<String, dynamic> json) =>
      JobQuotationDto(
        id: (json['id'] as String?) ?? '',
        applicationId: (json['application_id'] as String?) ?? '',
        proposedBy: (json['proposed_by'] as String?) ?? '',
        proposedAmount: _toDouble(json['proposed_amount']),
        currencyCode: (json['currency_code'] as String?) ?? 'NGN',
        durationDays: (json['duration_days'] as num?)?.toInt(),
        message: json['message'] as String?,
        revisionNumber: (json['revision_number'] as num?)?.toInt() ?? 1,
        status: (json['status'] as String?) ?? 'proposed',
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
        decidedAt: _parseNullableDateTime(json['decided_at']),
      );

  final String id;
  final String applicationId;
  final String proposedBy;
  final double proposedAmount;
  final String currencyCode;
  final int? durationDays;
  final String? message;
  final int revisionNumber;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? decidedAt;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
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
