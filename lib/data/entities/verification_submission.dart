import 'package:hivorr/systems/verification/models/document_type.dart';

/// The lifecycle status of a verification submission (EP-02-10).
///
/// Mirrors the server contract
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:133-135`).
enum VerificationStatusKind {
  /// Queued, awaiting review.
  pending,

  /// Under active review.
  inReview,

  /// Approved — assigned a KYC tier.
  approved,

  /// Rejected — see `decisionNotes`.
  rejected,

  /// Requires resubmission with corrected documents.
  requiresResubmission;

  /// Maps a server status string to the enum, defaulting to `pending`.
  static VerificationStatusKind fromServer(String? value) {
    return switch (value) {
      'in_review' => VerificationStatusKind.inReview,
      'approved' => VerificationStatusKind.approved,
      'rejected' => VerificationStatusKind.rejected,
      'requires_resubmission' => VerificationStatusKind.requiresResubmission,
      _ => VerificationStatusKind.pending,
    };
  }

  /// Whether this status is terminal (no further transitions are expected).
  bool get isTerminal => switch (this) {
        VerificationStatusKind.approved ||
        VerificationStatusKind.rejected ||
        VerificationStatusKind.requiresResubmission => true,
        VerificationStatusKind.pending ||
        VerificationStatusKind.inReview => false,
      };

  /// Whether this status represents a non-approved decision that needs action.
  bool get needsAction => switch (this) {
        VerificationStatusKind.rejected ||
        VerificationStatusKind.requiresResubmission => true,
        _ => false,
      };
}

/// A single identity-document verification submission (EP-02-10).
///
/// Pure Dart domain model — no framework or RPC JSON shape leaks through
/// (ARCHITECTURE.md separation).
class VerificationSubmission {
  const VerificationSubmission({
    required this.id,
    required this.entityId,
    required this.credentialId,
    required this.documentType,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.decisionNotes,
  });

  /// Submission id (UUID).
  final String id;

  /// Owning entity id.
  final String entityId;

  /// Reference to the `entity_credentials` trust-evidence row.
  final String credentialId;

  /// The document type used for this submission (identity vocabulary).
  final DocumentType documentType;

  /// Current lifecycle status.
  final VerificationStatusKind status;

  /// When the submission was queued.
  final DateTime submittedAt;

  /// When the submission was decided, if terminal.
  final DateTime? reviewedAt;

  /// Admin decision notes (rejection / resubmission reason), truncated to 5000.
  final String? decisionNotes;
}
