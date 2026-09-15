/// Pure Dart domain model for an approved credential on the public profile
/// page (EP-02-19).
///
/// Contains only whitelisted fields from the `portfolio_public_profile_get`
/// RPC projection — never `document_path`, `id`, `reviewed_by`, or
/// `rejection_reason`.
class PublicCredential {
  const PublicCredential({
    required this.kind,
    required this.title,
    required this.verificationStatus,
  });

  /// Credential kind vocabulary: `identity_document`, `trade_proof`,
  /// `certification`.
  final String kind;

  /// Display title of the credential.
  final String title;

  /// Always `approved` (the RPC filters to approved-only).
  final String verificationStatus;
}
