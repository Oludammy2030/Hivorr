import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';

/// The per-profession trade verification state (EP-02-11).
///
/// Mirrors the display states surfaced by the status screen timeline
/// (`Unverified → Submitted → Pending → Approved/Rejected`) and consumed by
/// [TradeVerificationGate.canBid]. The server `trade_verification_status`
/// column stores `unverified | pending | approved`
/// (`supabase/migrations/20260821090002_entity_core_tables.sql:184`) and
/// `rejected` is **derived client-side** (decision log #2) because the column
/// never stores it — a previously-submitted, non-approved proof reads as
/// rejected for UX.
///
/// Known limitation (identity audit): the binding row cannot distinguish
/// `in_review` from `pending`, nor `rejected` from `requires_resubmission`.
/// Screens needing the exact review state must join
/// `verification_submissions` (5-state source of truth) instead of relying
/// on this enum. Do not add states here without a matching server CHECK
/// change — the gating contract is `approved`-only either way.
enum TradeVerificationStatusKind {
  /// No submission yet — the DB default.
  unverified,

  /// A proof has been queued and is under review.
  pending,

  /// Approved — the `AGENT.md` Rule 2 bid-lock is released.
  approved,

  /// A proof was decided but not approved (rejected/requires resubmission),
  /// derived client-side.
  rejected;

  /// Maps a server `trade_verification_status` string to the enum, defaulting
  /// to [unverified] for the DB-default column value.
  static TradeVerificationStatusKind fromServer(String? value) {
    return switch (value) {
      'approved' => TradeVerificationStatusKind.approved,
      'pending' || 'in_review' => TradeVerificationStatusKind.pending,
      'rejected' ||
      'requires_resubmission' => TradeVerificationStatusKind.rejected,
      _ => TradeVerificationStatusKind.unverified,
    };
  }

  /// Whether this state releases the marketplace bid-lock (`AGENT.md:15`
  /// Rule 2). Only [approved] unlocks bidding.
  bool get canBid => this == TradeVerificationStatusKind.approved;

  /// Whether this state is terminal (no further transitions are expected
  /// without a fresh submission). [approved] and [rejected] are terminal;
  /// [unverified] and [pending] are not.
  bool get isTerminal =>
      this == TradeVerificationStatusKind.approved ||
      this == TradeVerificationStatusKind.rejected;
}

/// The trade-verification aggregate for the current entity (EP-02-11 §5.2).
///
/// Pure Dart domain model — no RPC JSON shape leaks through. Holds the
/// per-profession [TradeVerification] entries and the identity-verified flag,
/// mirroring the `trade_verifications` array + `identity_verified` fields of
/// `verification_status_get`
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:654-657`).
class TradeVerificationStatus {
  const TradeVerificationStatus({
    this.tradeVerifications = const <TradeVerification>[],
    this.identityVerified = false,
    this.latestSubmissions = const <VerificationSubmissionSummary>[],
  });

  /// The per-profession trade verification entries.
  final List<TradeVerification> tradeVerifications;

  /// Whether identity is verified (server-derived).
  final bool identityVerified;

  /// Latest persisted submissions from the review queue (identity + trade).
  ///
  /// Used to distinguish under-review from rejected; the binding column stays
  /// the sole authority for [kindFor] and the bid gate.
  final List<VerificationSubmissionSummary> latestSubmissions;

  /// The exact review state for [professionId], when the server projected it.
  VerificationSubmissionSummary? latestSubmissionFor(String professionId) {
    VerificationSubmissionSummary? latest;
    for (final VerificationSubmissionSummary row in latestSubmissions) {
      if (!row.isTradeProof) continue;
      if (row.professionId != null && row.professionId != professionId) {
        continue;
      }
      if (latest == null || row.submittedAt.isAfter(latest.submittedAt)) {
        latest = row;
      }
    }
    return latest;
  }

  /// The derived state for [professionId].
  ///
  /// Returns [TradeVerificationStatusKind.unverified] when the profession is
  /// absent from the aggregate (not yet bound/verified) — consistent with the
  /// `AGENT.md:15` Rule 2 bid-lock failure mode for unknown professions.
  TradeVerificationStatusKind kindFor(String professionId) {
    final TradeVerification entry = tradeVerifications.firstWhere(
      (TradeVerification e) => e.professionId == professionId,
      orElse: () => TradeVerification.unverified(professionId),
    );
    return entry.statusKind;
  }
}
