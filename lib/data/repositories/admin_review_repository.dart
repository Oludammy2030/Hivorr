/// Abstract contract for admin review data operations (EP-02-11 §5.3).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface (ARCHITECTURE.md).
abstract class AdminReviewRepository {
  /// Checks whether the current user is a platform admin.
  Future<bool> checkAdmin();

  /// Returns the pending review queue.
  Future<List<AdminReviewQueueEntry>> getReviewQueue({
    String? submissionType,
    int limit = 50,
    int offset = 0,
    String? search,
    String? professionId,
    String? sort,
  });

  /// Claims a submission for review (sets status to `in_review`).
  Future<void> startReview(String submissionId);

  /// Approves a submission.
  Future<void> approveSubmission(String submissionId, {String notes = ''});

  /// Rejects a submission (optionally requiring resubmission).
  Future<void> rejectSubmission(
    String submissionId, {
    String notes = '',
    bool requiresResubmission = false,
  });

  /// Returns the audit trail for a submission.
  Future<List<AdminReviewAuditEntry>> getAuditTrail(String submissionId);

  /// Returns the applicant profile depth (experience, education, skills)
  /// for one submission, resolved server-side via its entity.
  ///
  /// Backed by `verification_review_profile_get`. Empty lists mean the
  /// applicant recorded nothing — never an error.
  Future<AdminReviewProfile> getReviewProfile(String submissionId);

  /// Creates a short-lived signed URL for viewing a credential document.
  Future<String> createDocumentSignedUrl(String credentialId, {int expiresIn});

  /// Returns verification throughput metrics for the dashboard metrics row.
  ///
  /// Backed by `verification_review_metrics_get`. [periodDays] is the
  /// trailing window (1–365); [submissionType] optionally scopes every
  /// aggregate to one submission type.
  Future<AdminReviewMetrics> getReviewMetrics({
    int periodDays = 30,
    String? submissionType,
  });

  /// The server `total_count` from the most recent queue fetch, or `null`
  /// before the first successful load. Lets the metrics row show the real
  /// pending total instead of the loaded-page length.
  int? get lastTotalCount;
}

/// A single entry in the admin review queue.
///
/// The registered-vs-submitted comparison (Phase 3 of the Verification &
/// Approval plan) needs the registered identity alongside the submission:
/// [entityLegalName], [professionId]/[professionName], [documentPath],
/// [assignedReviewer], and [decisionNotes] are carried verbatim from the
/// DTO — never derived client-side.
class AdminReviewQueueEntry {
  const AdminReviewQueueEntry({
    required this.submissionId,
    required this.entityId,
    required this.entityName,
    required this.credentialId,
    required this.credentialType,
    required this.credentialName,
    required this.submissionType,
    required this.status,
    required this.submittedAt,
    this.entityAvatarPath,
    this.entityLegalName,
    this.documentPath,
    this.professionId,
    this.professionName,
    this.assignedReviewer,
    this.decisionNotes,
  });

  final String submissionId;
  final String entityId;
  final String entityName;
  final String credentialId;
  final String credentialType;
  final String credentialName;
  final String submissionType;
  final String status;
  final DateTime submittedAt;
  final String? entityAvatarPath;

  /// Registered legal name for comparison (may legitimately differ from
  /// [entityName]; a mismatch is a prompt to look, never evidence of fraud).
  final String? entityLegalName;

  /// Server document path for the credential (signed URLs stay short-lived).
  final String? documentPath;
  final String? professionId;
  final String? professionName;
  final String? assignedReviewer;
  final String? decisionNotes;
}

/// A single entry in the verification audit trail.
class AdminReviewAuditEntry {
  const AdminReviewAuditEntry({
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

  final String id;
  final String eventType;
  final String? subjectType;
  final String? subjectId;
  final String? fromState;
  final String? toState;
  final String? actorId;
  final Map<String, dynamic>? detailsJson;
  final DateTime createdAt;
}

/// Verification throughput metrics for the dashboard metrics row.
///
/// Mirrors `AdminReviewMetricsDto` verbatim. `avgVerificationSeconds` and
/// `rejectionRate` are `null` when the trailing window holds no decided
/// rows — the UI renders "Unavailable", never zero.
class AdminReviewMetrics {
  const AdminReviewMetrics({
    required this.pendingTotal,
    required this.inReviewTotal,
    this.avgVerificationSeconds,
    required this.approvedToday,
    required this.decidedTotal,
    required this.rejectedTotal,
    this.rejectionRate,
    required this.periodDays,
  });

  final int pendingTotal;
  final int inReviewTotal;
  final double? avgVerificationSeconds;
  final int approvedToday;
  final int decidedTotal;
  final int rejectedTotal;
  final double? rejectionRate;
  final int periodDays;
}

/// Applicant profile depth for one verification submission.
class AdminReviewProfile {
  const AdminReviewProfile({
    this.experiences = const <ReviewExperience>[],
    this.educations = const <ReviewEducation>[],
    this.skills = const <ReviewSkill>[],
  });

  final List<ReviewExperience> experiences;
  final List<ReviewEducation> educations;
  final List<ReviewSkill> skills;
}

/// One employment record (dates as year/month + current flag).
class ReviewExperience {
  const ReviewExperience({
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

  final String id;
  final String title;
  final String organization;
  final int? startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;
  final String? description;
}

/// One education record.
class ReviewEducation {
  const ReviewEducation({
    required this.id,
    required this.school,
    this.degree,
    this.fieldOfStudy,
    this.graduationYear,
  });

  final String id;
  final String school;
  final String? degree;
  final String? fieldOfStudy;
  final int? graduationYear;
}

/// One skill (years only — no proficiency scale is collected).
class ReviewSkill {
  const ReviewSkill({
    required this.id,
    required this.name,
    this.yearsExperience,
  });

  final String id;
  final String name;
  final int? yearsExperience;
}
