/// Data Transfer Object for a `jobs` row (EP-04-01).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260928090001_jobs_applications_schema.sql:44-95`),
/// using the actual snake_case keys returned inside the `job_*` envelopes.
class JobDto {
  const JobDto({
    required this.id,
    required this.clientEntityId,
    this.professionId,
    this.industryId,
    required this.title,
    required this.description,
    this.budgetMin,
    this.budgetMax,
    required this.currencyCode,
    this.location,
    required this.status,
    this.applicationsCount = 0,
    this.awardedApplicationId,
    this.postedAt,
    this.awardedAt,
    this.completedAt,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobDto.fromJson(Map<String, dynamic> json) => JobDto(
    id: (json['id'] as String?) ?? '',
    clientEntityId: (json['client_entity_id'] as String?) ?? '',
    professionId: json['profession_id'] as String?,
    industryId: json['industry_id'] as String?,
    title: (json['title'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    budgetMin: _toNullableDouble(json['budget_min']),
    budgetMax: _toNullableDouble(json['budget_max']),
    currencyCode: (json['currency_code'] as String?) ?? 'NGN',
    location: json['location'] as String?,
    status: (json['status'] as String?) ?? 'draft',
    applicationsCount: (json['applications_count'] as num?)?.toInt() ?? 0,
    awardedApplicationId: json['awarded_application_id'] as String?,
    postedAt: _parseNullableDateTime(json['posted_at']),
    awardedAt: _parseNullableDateTime(json['awarded_at']),
    completedAt: _parseNullableDateTime(json['completed_at']),
    cancelledAt: _parseNullableDateTime(json['cancelled_at']),
    createdAt: _parseDateTime(json['created_at']),
    updatedAt: _parseDateTime(json['updated_at']),
  );

  final String id;
  final String clientEntityId;
  final String? professionId;
  final String? industryId;
  final String title;
  final String description;
  final double? budgetMin;
  final double? budgetMax;
  final String currencyCode;
  final String? location;
  final String status;
  final int applicationsCount;
  final String? awardedApplicationId;
  final DateTime? postedAt;
  final DateTime? awardedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

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
