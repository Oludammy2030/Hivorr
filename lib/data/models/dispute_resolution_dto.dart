/// Data Transfer Object for a `dispute_resolutions` row (EP-02-17).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:135-152`),
/// using the actual snake_case keys returned inside the `dispute_get`
/// envelope. Numeric amounts arrive as `numeric` (JSON number-or-string) and
/// are normalized to [double] here.
class DisputeResolutionDto {
  const DisputeResolutionDto({
    required this.id,
    required this.caseId,
    this.resolvedBy,
    required this.resolutionType,
    required this.reasoning,
    this.payerRefundAmount = 0.0,
    this.payeeReleaseAmount = 0.0,
    this.notes,
    required this.resolvedAt,
    required this.createdAt,
  });

  factory DisputeResolutionDto.fromJson(Map<String, dynamic> json) =>
      DisputeResolutionDto(
        id: (json['id'] as String?) ?? '',
        caseId: (json['case_id'] as String?) ?? '',
        resolvedBy: json['resolved_by'] as String?,
        resolutionType: (json['resolution_type'] as String?) ?? '',
        reasoning: (json['reasoning'] as String?) ?? '',
        payerRefundAmount: _toDouble(json['payer_refund_amount']),
        payeeReleaseAmount: _toDouble(json['payee_release_amount']),
        notes: json['notes'] as String?,
        resolvedAt: _parseDateTime(json['resolved_at']),
        createdAt: _parseDateTime(json['created_at']),
      );

  final String id;
  final String caseId;
  final String? resolvedBy;
  final String resolutionType;
  final String reasoning;
  final double payerRefundAmount;
  final double payeeReleaseAmount;
  final String? notes;
  final DateTime resolvedAt;
  final DateTime createdAt;

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
}