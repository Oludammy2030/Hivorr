/// Data Transfer Object for a `hires` row (EP-04-02).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260928090002_quotations_hires_schema.sql:84-125`).
/// `effective_status`/`job_title`/`job_status` are computed payload fields
/// present only in the `hire_get`/`hire_list_mine` envelopes.
class HireDto {
  const HireDto({
    required this.id,
    required this.jobId,
    required this.applicationId,
    this.quotationId,
    required this.clientEntityId,
    required this.professionalEntityId,
    this.contractId,
    required this.status,
    required this.hiredAt,
    this.completedAt,
    this.cancelledAt,
    this.effectiveStatus,
    this.jobTitle,
    this.jobStatus,
  });

  factory HireDto.fromJson(Map<String, dynamic> json) => HireDto(
    id: (json['id'] as String?) ?? '',
    jobId: (json['job_id'] as String?) ?? '',
    applicationId: (json['application_id'] as String?) ?? '',
    quotationId: json['quotation_id'] as String?,
    clientEntityId: (json['client_entity_id'] as String?) ?? '',
    professionalEntityId: (json['professional_entity_id'] as String?) ?? '',
    contractId: json['contract_id'] as String?,
    status: (json['status'] as String?) ?? 'pending',
    hiredAt: _parseDateTime(json['hired_at']),
    completedAt: _parseNullableDateTime(json['completed_at']),
    cancelledAt: _parseNullableDateTime(json['cancelled_at']),
    effectiveStatus: json['effective_status'] as String?,
    jobTitle: json['job_title'] as String?,
    jobStatus: json['job_status'] as String?,
  );

  final String id;
  final String jobId;
  final String applicationId;
  final String? quotationId;
  final String clientEntityId;
  final String professionalEntityId;
  final String? contractId;
  final String status;
  final DateTime hiredAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? effectiveStatus;
  final String? jobTitle;
  final String? jobStatus;

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
