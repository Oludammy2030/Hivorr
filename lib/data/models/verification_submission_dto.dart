/// Data Transfer Object mirroring a `verification_submissions` row (EP-02-10).
///
/// Field names are camelCase in Dart but map the server snake_case columns
/// exactly via [fromJson] to avoid silent deserialization drift
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:115-143`).
/// Optional fields tolerate `null`.
class VerificationSubmissionDto {
  const VerificationSubmissionDto({
    required this.id,
    required this.entityId,
    required this.credentialId,
    required this.submissionType,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.decisionNotes,
  });

  /// Parses a single verification submission RPC/table row.
  factory VerificationSubmissionDto.fromJson(Map<String, dynamic> json) {
    return VerificationSubmissionDto(
      id: json['id'] as String,
      entityId: json['entity_id'] as String,
      credentialId: json['credential_id'] as String,
      submissionType: (json['submission_type'] as String?) ??
          DocumentTypeDto.identityDocument,
      status: (json['status'] as String?) ?? 'pending',
      submittedAt: _parseDate(json['submitted_at']) ?? DateTime.now(),
      reviewedAt: _parseDate(json['reviewed_at']),
      decisionNotes: json['decision_notes'] as String?,
    );
  }

  final String id;
  final String entityId;
  final String credentialId;
  final String submissionType;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? decisionNotes;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Canonical server submission-type string for identity documents.
abstract final class DocumentTypeDto {
  const DocumentTypeDto._();

  /// `identity_document` — the only submission type this task emits.
  static const String identityDocument = 'identity_document';
}
