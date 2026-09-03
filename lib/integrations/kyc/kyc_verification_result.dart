/// Result of a KYC provider verification attempt (EP-02-12 §7.3).
///
/// Display-only — the server re-reads `getKycLevel()` after the provider signals
/// approval; this result never grants local state (prevents spoofed state).
class KycVerificationResult {
  const KycVerificationResult({
    required this.status,
    this.providerReference,
  });

  /// The provider-reported status (`pending`, `approved`, `rejected`).
  final String status;

  /// Optional provider reference for later server polling.
  final String? providerReference;

  /// Whether the provider reported approval synchronously.
  bool get isApproved => status == 'approved';

  /// Whether the provider reported a pending review.
  bool get isPending => status == 'pending';
}
