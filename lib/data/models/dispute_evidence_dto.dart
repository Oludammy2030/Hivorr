/// Data Transfer Object for a `dispute_evidence` row (EP-02-17).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:106-122`),
/// using the actual snake_case keys returned inside the
/// `dispute_submit_evidence` / `dispute_get` envelopes.
class DisputeEvidenceDto {
  const DisputeEvidenceDto({
    required this.id,
    required this.caseId,
    required this.submittedBy,
    required this.evidenceType,
    required this.title,
    this.description,
    this.fileUrl,
    this.fileMetadata = const <String, dynamic>{},
    required this.createdAt,
  });

  factory DisputeEvidenceDto.fromJson(Map<String, dynamic> json) =>
      DisputeEvidenceDto(
        id: (json['id'] as String?) ?? '',
        caseId: (json['case_id'] as String?) ?? '',
        submittedBy: (json['submitted_by'] as String?) ?? '',
        evidenceType: (json['evidence_type'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: json['description'] as String?,
        fileUrl: json['file_url'] as String?,
        fileMetadata: (json['file_metadata'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
        createdAt: _parseDateTime(json['created_at']),
      );

  final String id;
  final String caseId;
  final String submittedBy;
  final String evidenceType;
  final String title;
  final String? description;
  final String? fileUrl;
  final Map<String, dynamic> fileMetadata;
  final DateTime createdAt;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}