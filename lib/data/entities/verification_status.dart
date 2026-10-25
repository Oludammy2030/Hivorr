import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';

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
    this.professionalDisplayName,
  });

  /// Builds an [unverified] placeholder for an absent profession (EP-02-11).
  const TradeVerification.unverified(String professionId)
    : this(professionId: professionId, status: 'unverified');

  /// The bound profession id.
  final String professionId;

  /// Trade verification status (read-only display).
  final String status;

  /// Proposed public professional name for this binding (null until
  /// supplied; effective for display only when [statusKind] is approved —
  /// enforced by readers, see the Phase 2 context resolver).
  final String? professionalDisplayName;

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
    this.latestSubmissions = const <VerificationSubmissionSummary>[],
    this.hasLatestSubmissionData = false,
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

  /// Latest persisted submission per `(submission_type, profession)`.
  ///
  /// The review state surfaces here even though the binding columns keep only
  /// `unverified | pending | approved`; the server projects it from
  /// `verification_submissions`.
  final List<VerificationSubmissionSummary> latestSubmissions;

  /// Whether [latestSubmissions] reflects the server projection.
  ///
  /// `false` for old aggregates that only carry counters; callers then fall
  /// back to [pendingSubmissions]/[totalSubmissions] instead of reading an
  /// empty list as "never submitted".
  final bool hasLatestSubmissionData;

  /// Number of pending submissions.
  final int pendingSubmissions;

  /// Total number of submissions.
  final int totalSubmissions;

  /// The most recent identity/certification submission, if any.
  VerificationSubmissionSummary? get latestIdentitySubmission =>
      _latestWhere((VerificationSubmissionSummary row) => row.isIdentity);

  /// Every latest trade-proof submission (one per profession).
  List<VerificationSubmissionSummary> get latestTradeSubmissions =>
      latestSubmissions
          .where((VerificationSubmissionSummary row) => row.isTradeProof)
          .toList(growable: false);

  /// The latest trade-proof submission for [professionId].
  ///
  /// Falls back to the newest trade row when the server did not attach a
  /// profession id to a legacy credential.
  VerificationSubmissionSummary? latestTradeSubmissionFor(String professionId) {
    final VerificationSubmissionSummary? exact = _latestWhere(
      (VerificationSubmissionSummary row) =>
          row.isTradeProof && row.professionId == professionId,
    );
    if (exact != null) return exact;
    // Legacy server rows may omit the profession binding; only fall back to
    // those, never to another profession's decision.
    return _latestWhere(
      (VerificationSubmissionSummary row) =>
          row.isTradeProof && row.professionId == null,
    );
  }

  /// The newest trade-proof submission across all professions, if any.
  VerificationSubmissionSummary? get latestTradeSubmission =>
      _latestWhere((VerificationSubmissionSummary row) => row.isTradeProof);

  VerificationSubmissionSummary? _latestWhere(
    bool Function(VerificationSubmissionSummary row) test,
  ) {
    VerificationSubmissionSummary? latest;
    for (final VerificationSubmissionSummary row in latestSubmissions) {
      if (!test(row)) continue;
      if (latest == null || row.submittedAt.isAfter(latest.submittedAt)) {
        latest = row;
      }
    }
    return latest;
  }
}
