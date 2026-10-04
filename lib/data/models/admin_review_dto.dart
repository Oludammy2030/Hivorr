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
  const AdminCheckResultDto({required this.isPlatformAdmin});

  factory AdminCheckResultDto.fromJson(Map<String, dynamic> json) {
    return AdminCheckResultDto(
      isPlatformAdmin: (json['is_admin'] as bool?) ?? false,
    );
  }

  final bool isPlatformAdmin;
}

/// Verification throughput metrics returned by
/// `verification_review_metrics_get` (Phase 2).
///
/// Canonical server data: `{ pending_total, in_review_total,
/// avg_verification_seconds, approved_today, decided_total, rejected_total,
/// rejection_rate, period_days }`. Averages and rates are `null` when the
/// window holds no decided rows — the UI renders "Unavailable", never zero.
class AdminReviewMetricsDto {
  const AdminReviewMetricsDto({
    required this.pendingTotal,
    required this.inReviewTotal,
    this.avgVerificationSeconds,
    required this.approvedToday,
    required this.decidedTotal,
    required this.rejectedTotal,
    this.rejectionRate,
    required this.periodDays,
  });

  factory AdminReviewMetricsDto.fromJson(Map<String, dynamic> json) {
    return AdminReviewMetricsDto(
      pendingTotal: _asInt(json['pending_total']) ?? 0,
      inReviewTotal: _asInt(json['in_review_total']) ?? 0,
      avgVerificationSeconds: _asDouble(json['avg_verification_seconds']),
      approvedToday: _asInt(json['approved_today']) ?? 0,
      decidedTotal: _asInt(json['decided_total']) ?? 0,
      rejectedTotal: _asInt(json['rejected_total']) ?? 0,
      rejectionRate: _asDouble(json['rejection_rate']),
      periodDays: _asInt(json['period_days']) ?? 30,
    );
  }

  final int pendingTotal;
  final int inReviewTotal;
  final double? avgVerificationSeconds;
  final int approvedToday;
  final int decidedTotal;
  final int rejectedTotal;
  final double? rejectionRate;
  final int periodDays;

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Applicant profile depth from `verification_review_profile_get`.
///
/// Canonical server data: `{ experiences[], educations[], skills[] }`.
/// Missing arrays decode as empty — an applicant with no recorded history
/// is valid, never an error.
class AdminReviewProfileDto {
  const AdminReviewProfileDto({
    this.experiences = const <ReviewExperienceDto>[],
    this.educations = const <ReviewEducationDto>[],
    this.skills = const <ReviewSkillDto>[],
  });

  factory AdminReviewProfileDto.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(
      Object? value,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (value is! List) return <T>[];
      return value
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    }

    return AdminReviewProfileDto(
      experiences: listOf(json['experiences'], ReviewExperienceDto.fromJson),
      educations: listOf(json['educations'], ReviewEducationDto.fromJson),
      skills: listOf(json['skills'], ReviewSkillDto.fromJson),
    );
  }

  final List<ReviewExperienceDto> experiences;
  final List<ReviewEducationDto> educations;
  final List<ReviewSkillDto> skills;
}

/// One work-experience row from `verification_review_profile_get`.
class ReviewExperienceDto {
  const ReviewExperienceDto({
    required this.id,
    required this.title,
    required this.organization,
    this.startYear,
    this.startMonth,
    this.endYear,
    this.endMonth,
    required this.isCurrent,
    this.description,
  });

  factory ReviewExperienceDto.fromJson(Map<String, dynamic> json) {
    return ReviewExperienceDto(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      organization: (json['organization'] as String?) ?? '',
      startYear: _asInt(json['start_year']),
      startMonth: _asInt(json['start_month']),
      endYear: _asInt(json['end_year']),
      endMonth: _asInt(json['end_month']),
      isCurrent: (json['is_current'] as bool?) ?? false,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String title;
  final String organization;
  final int? startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;
  final String? description;

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// One education row from `verification_review_profile_get`.
class ReviewEducationDto {
  const ReviewEducationDto({
    required this.id,
    required this.school,
    this.degree,
    this.fieldOfStudy,
    this.graduationYear,
  });

  factory ReviewEducationDto.fromJson(Map<String, dynamic> json) {
    return ReviewEducationDto(
      id: (json['id'] as String?) ?? '',
      school: (json['school'] as String?) ?? '',
      degree: json['degree'] as String?,
      fieldOfStudy: json['field_of_study'] as String?,
      graduationYear: ReviewExperienceDto._asInt(json['graduation_year']),
    );
  }

  final String id;
  final String school;
  final String? degree;
  final String? fieldOfStudy;
  final int? graduationYear;
}

/// One skill row from `verification_review_profile_get` (years only —
/// the platform collects no proficiency scale).
class ReviewSkillDto {
  const ReviewSkillDto({
    required this.id,
    required this.name,
    this.yearsExperience,
  });

  factory ReviewSkillDto.fromJson(Map<String, dynamic> json) {
    return ReviewSkillDto(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      yearsExperience: ReviewExperienceDto._asInt(json['years_experience']),
    );
  }

  final String id;
  final String name;
  final int? yearsExperience;
}
