// Data Transfer Objects for the admin review queue and audit trail RPCs
// (EP-02-11).
//
// Field names are camelCase in Dart but map the server snake_case columns
// exactly via [fromJson] to avoid silent deserialization drift. The canonical
// shapes below are locked server-side by
// supabase/tests/database/021_admin_review_contract.sql; the client adopts
// them verbatim (migration 20260917090001).

/// A single queue entry returned by `verification_review_queue_get`.
///
/// Canonical server row (data.submissions[]):
///   id, entity_id, entity_display_name, entity_legal_name,
///   entity_avatar_path, credential_id, credential_title, credential_kind,
///   document_path, profession_id, profession_name, submission_type, status,
///   submitted_at, assigned_reviewer, decision_notes
class AdminReviewQueueEntryDto {
  const AdminReviewQueueEntryDto({
    required this.submissionId,
    required this.entityId,
    required this.entityName,
    required this.entityLegalName,
    this.entityAvatarPath,
    required this.credentialId,
    required this.credentialType,
    required this.credentialName,
    required this.submissionType,
    required this.status,
    required this.submittedAt,
    this.documentPath,
    this.professionId,
    this.professionName,
    this.assignedReviewer,
    this.decisionNotes,
  });

  factory AdminReviewQueueEntryDto.fromJson(Map<String, dynamic> json) {
    return AdminReviewQueueEntryDto(
      submissionId: json['id'] as String,
      entityId: json['entity_id'] as String,
      entityName: (json['entity_display_name'] as String?) ?? '',
      entityLegalName: json['entity_legal_name'] as String?,
      entityAvatarPath: json['entity_avatar_path'] as String?,
      credentialId: json['credential_id'] as String,
      credentialType: (json['credential_kind'] as String?) ?? '',
      credentialName: (json['credential_title'] as String?) ?? '',
      submissionType: (json['submission_type'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      submittedAt: _parseDate(json['submitted_at']) ?? DateTime.now(),
      documentPath: json['document_path'] as String?,
      professionId: json['profession_id'] as String?,
      professionName: json['profession_name'] as String?,
      assignedReviewer: json['assigned_reviewer'] as String?,
      decisionNotes: json['decision_notes'] as String?,
    );
  }

  final String submissionId;
  final String entityId;
  final String entityName;
  final String? entityLegalName;
  final String? entityAvatarPath;
  final String credentialId;
  final String credentialType;
  final String credentialName;
  final String submissionType;
  final String status;
  final DateTime submittedAt;
  final String? documentPath;
  final String? professionId;
  final String? professionName;
  final String? assignedReviewer;
  final String? decisionNotes;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// A single audit trail entry returned by `verification_review_audit_get`.
///
/// Canonical server row (data.audit_entries[]):
///   id, event_type, subject_type, subject_id, from_state, to_state,
///   actor_id, details, created_at
class AdminReviewAuditEntryDto {
  const AdminReviewAuditEntryDto({
    required this.id,
    required this.eventType,
    this.subjectType,
    this.subjectId,
    this.fromState,
    this.toState,
    this.actorId,
    this.detailsJson,
    required this.createdAt,
  });

  factory AdminReviewAuditEntryDto.fromJson(Map<String, dynamic> json) {
    return AdminReviewAuditEntryDto(
      id: json['id'] as String,
      eventType: (json['event_type'] as String?) ?? '',
      subjectType: json['subject_type'] as String?,
      subjectId: json['subject_id'] as String?,
      fromState: json['from_state'] as String?,
      toState: json['to_state'] as String?,
      actorId: json['actor_id'] as String?,
      detailsJson: json['details'] as Map<String, dynamic>?,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final String eventType;
  final String? subjectType;
  final String? subjectId;
  final String? fromState;
  final String? toState;
  final String? actorId;
  final Map<String, dynamic>? detailsJson;
  final DateTime createdAt;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Admin check result returned by `platform_admin_check`.
///
/// Canonical server data: `{ 'is_admin': bool }`. There is intentionally no
/// entity_id on the wire; the client only consumes the boolean.
class AdminCheckResultDto {
  const AdminCheckResultDto({
    required this.isPlatformAdmin,
  });

  factory AdminCheckResultDto.fromJson(Map<String, dynamic> json) {
    return AdminCheckResultDto(
      isPlatformAdmin: (json['is_admin'] as bool?) ?? false,
    );
  }

  final bool isPlatformAdmin;
}