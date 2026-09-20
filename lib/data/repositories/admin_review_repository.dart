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

  /// Creates a short-lived signed URL for viewing a credential document.
  Future<String> createDocumentSignedUrl(String credentialId, {int expiresIn});
}

/// A single entry in the admin review queue.
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
