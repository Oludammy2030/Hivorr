/// Data Transfer Object for a `job_applications` row (EP-04-01).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260928090001_jobs_applications_schema.sql:108-152`),
/// using the actual snake_case keys returned inside the `application_*`
/// envelopes. `job_title`/`job_status` are present only in
/// `application_list_mine`.
class JobApplicationDto {
  const JobApplicationDto({
    required this.id,
    required this.jobId,
    required this.professionalEntityId,
    required this.clientEntityId,
    required this.coverNote,
    this.quotedAmount,
    required this.currencyCode,
    this.durationDays,
    required this.status,
    required this.submittedAt,
    this.decidedAt,
    required this.createdAt,
    required this.updatedAt,
    this.jobTitle,
    this.jobStatus,
  });

  factory JobApplicationDto.fromJson(Map<String, dynamic> json) =>
      JobApplicationDto(
        id: (json['id'] as String?) ?? '',
        jobId: (json['job_id'] as String?) ?? '',
        professionalEntityId: (json['professional_entity_id'] as String?) ?? '',
        clientEntityId: (json['client_entity_id'] as String?) ?? '',
        coverNote: (json['cover_note'] as String?) ?? '',
        quotedAmount: _toNullableDouble(json['quoted_amount']),
        currencyCode: (json['currency_code'] as String?) ?? 'NGN',
        durationDays: (json['duration_days'] as num?)?.toInt(),
        status: (json['status'] as String?) ?? 'submitted',
        submittedAt: _parseDateTime(json['submitted_at']),
        decidedAt: _parseNullableDateTime(json['decided_at']),
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
        jobTitle: json['job_title'] as String?,
        jobStatus: json['job_status'] as String?,
      );

  final String id;
  final String jobId;
  final String professionalEntityId;
  final String clientEntityId;
  final String coverNote;
  final double? quotedAmount;
  final String currencyCode;
  final int? durationDays;
  final String status;
  final DateTime submittedAt;
  final DateTime? decidedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? jobTitle;
  final String? jobStatus;

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is num) return value.toDouble();
    return null;
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
