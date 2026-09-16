import 'package:hivorr/data/models/admin_review_dto.dart';

/// Abstract contract for the remote (Supabase) side of admin review operations
/// (EP-02-11 §5.2).
///
/// Implementations access the backend only through the EP-01-07
/// [BaseApiService] channel and the admin RPCs. Admin authorization is
/// server-enforced (`is_platform_admin()`); the client never caches or trusts
/// the admin flag beyond the current session.
abstract class AdminReviewRemoteDataSource {
  /// Checks whether the current user is a platform admin.
  ///
  /// Backed by `platform_admin_check`. Returns an [AdminCheckResultDto] on
  /// success; throws [ApiException] `PLT002` for non-admin callers.
  Future<AdminCheckResultDto> checkAdmin();

  /// Returns the pending review queue.
  ///
  /// Backed by `verification_review_queue_get`. Filters optional
  /// [submissionType] and applies cursor-based pagination with [limit] and
  /// [offset].
  Future<List<AdminReviewQueueEntryDto>> getReviewQueue({
    String? submissionType,
    int limit = 50,
    int offset = 0,
  });

  /// Claims a submission for review (sets status to `in_review`).
  ///
  /// Backed by `verification_review_start`.
  Future<void> startReview(String submissionId);

  /// Approves a submission.
  ///
  /// Backed by `verification_review_approve`.
  Future<void> approveSubmission(String submissionId, {String notes});

  /// Rejects a submission (optionally requiring resubmission).
  ///
  /// Backed by `verification_review_reject`.
  Future<void> rejectSubmission(
    String submissionId, {
    String notes,
    bool requiresResubmission = false,
  });

  /// Returns the audit trail for a submission.
  ///
  /// Backed by `verification_review_audit_get`.
  Future<List<AdminReviewAuditEntryDto>> getAuditTrail(String submissionId);

  /// Creates a short-lived signed URL for viewing a credential document.
  ///
  /// The client calls `storage.from('credential-documents').createSignedUrl()`
  /// directly; the server RLS policy grants SELECT to platform admins only.
  /// This method is a convenience wrapper that delegates to the storage API.
  Future<String> createDocumentSignedUrl(
    String credentialId, {
    int expiresIn = 60,
  });
}
