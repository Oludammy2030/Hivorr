import 'package:hivorr/data/entities/kyc_level.dart';

/// A single trade-verification entry within the identity verification
/// aggregate (EP-02-10).
///
/// Display-only for this task: `trade_verification_status` is **never** written
/// by the client (server-authoritative, `AGENT.md` Rule 4). The full trade
/// workflow is owned by EP-02-11.
class TradeVerification {
  const TradeVerification({
    required this.professionId,
    required this.status,
  });

  /// The bound profession id.
  final String professionId;

  /// Trade verification status (read-only display).
  final String status;
}

/// The full identity-verification aggregate surfaced by
/// `verification_status_get` (EP-02-10).
///
/// Combines the assigned [kycLevel], the `identity_verified` flag, the list of
/// (display-only) [tradeVerifications], and submission counters — all as pure
/// Dart domain models with no RPC JSON shape leaking through.
class VerificationStatus {
  const VerificationStatus({
    required this.entityId,
    required this.kycLevel,
    required this.identityVerified,
    this.tradeVerifications = const <TradeVerification>[],
    required this.pendingSubmissions,
    required this.totalSubmissions,
  });

  /// Owning entity id.
  final String entityId;

  /// The currently assigned KYC tier + limits.
  final KycLevel kycLevel;

  /// Whether identity is verified (server-derived).
  final bool identityVerified;

  /// Display-only trade verifications (empty for identity-only, EP-02-10).
  final List<TradeVerification> tradeVerifications;

  /// Number of pending submissions.
  final int pendingSubmissions;

  /// Total number of submissions.
  final int totalSubmissions;
}
