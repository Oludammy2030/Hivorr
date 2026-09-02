import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';

/// A single trade-verification entry within the identity verification
/// aggregate (EP-02-10).
///
/// Display-only: `trade_verification_status` is **never** written by the
/// client (server-authoritative, `AGENT.md` Rule 4). The full trade workflow is
/// owned by EP-02-11, which consumes [statusKind] for the gate + timeline.
class TradeVerification {
  const TradeVerification({
    required this.professionId,
    required this.status,
  });

  /// Builds an [unverified] placeholder for an absent profession (EP-02-11).
  const TradeVerification.unverified(String professionId)
      : this(professionId: professionId, status: 'unverified');

  /// The bound profession id.
  final String professionId;

  /// Trade verification status (read-only display).
  final String status;

  /// The typed trade-verification state derived from [status]
  /// (EP-02-11 §5.2 / decision log #2).
  TradeVerificationStatusKind get statusKind =>
      TradeVerificationStatusKind.fromServer(status);
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
