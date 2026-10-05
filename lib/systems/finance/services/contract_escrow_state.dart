// ignore_for_file: prefer_initializing_formals

/// Release-sequence state for one contract milestone (EP-03-11 §8 S3).
///
/// Pure Dart — no Flutter/Supabase imports. The orchestrator produces these
/// from server-authoritative reads (`service_contract_get` via
/// [ContractService], `financial_escrow_get` via [EscrowService]); the UI
/// renders them and never decides eligibility itself (`AGENT.md` Rule 4).
library;

/// Lifecycle phase of a single verify-and-release sequence.
enum ContractEscrowReleasePhase {
  /// No sequence running; the state is a cached read projection.
  idle,

  /// Pre-flight reads in flight (`contract_get` + `escrow_get`).
  checking,

  /// Client acceptance RPC in flight (`service_contract_verify_milestone`).
  verifying,

  /// Fund-movement RPC in flight (proxy -> `service_role` release).
  releasing,

  /// Funds moved; both re-reads confirm the released state.
  released,

  /// Sequence refused before fund movement (see [ContractEscrowBlockReason]).
  blocked,

  /// Sequence failed after passing pre-flight (transport / server error).
  failed,
}

/// Machine-readable refusal reason for [ContractEscrowReleasePhase.blocked].
///
/// Mirrors the server gate vocabulary (`service_contract_release_gate`):
/// `disputed | not-verified | not-funded | write-unavailable |
/// already-released`. `expired` is *eligible* (auto-release path), never a
/// block reason — the cron releases it server-side.
enum ContractEscrowBlockReason {
  /// Contract or escrow is `disputed` (freeze honored).
  disputed,

  /// Milestone is `pending` or `completed`-unexpired (needs verify first).
  notVerified,

  /// No linked escrow, or escrow not in `funded/partially_released`.
  notFunded,

  /// The Edge proxy write seam is off (`EscrowWriteUnavailableException`).
  writeUnavailable,

  /// Milestone already `released` (idempotent no-op).
  alreadyReleased,
}

/// Point-in-time release state for one contract milestone.
class ContractEscrowReleaseState {
  const ContractEscrowReleaseState({
    required this.contractId,
    required this.milestoneId,
    this.escrowId,
    this.escrowMilestoneId,
    this.phase = ContractEscrowReleasePhase.idle,
    this.blockReason,
    this.releasedAmount,
    this.serverTimestamp,
    this.message,
    this.code,
  });

  /// Owning `service_contracts` row.
  final String contractId;

  /// Owning `contract_milestones` row.
  final String milestoneId;

  /// Linked `financial_escrow` row (`null` until funded + linked).
  final String? escrowId;

  /// Linked `financial_escrow_milestones` row (`null` until linked).
  final String? escrowMilestoneId;

  /// Current sequence phase.
  final ContractEscrowReleasePhase phase;

  /// Why the sequence was refused (when [phase] is blocked).
  final ContractEscrowBlockReason? blockReason;

  /// Funds moved by a completed release (from the server re-read).
  final double? releasedAmount;

  /// Server timestamp anchoring countdowns (never client clock).
  final DateTime? serverTimestamp;

  /// Safe display message for the current phase.
  final String? message;

  /// Platform envelope code (`PLT000` on success, `PLT00x` on refusal).
  final String? code;

  /// Whether funds moved in this sequence.
  bool get ok => phase == ContractEscrowReleasePhase.released;

  /// Whether the UI should offer a release action for this state.
  bool get isReleasable =>
      phase == ContractEscrowReleasePhase.idle &&
      blockReason == null;

  ContractEscrowReleaseState copyWith({
    ContractEscrowReleasePhase? phase,
    ContractEscrowBlockReason? blockReason,
    String? escrowId,
    String? escrowMilestoneId,
    double? releasedAmount,
    DateTime? serverTimestamp,
    String? message,
    String? code,
  }) => ContractEscrowReleaseState(
    contractId: contractId,
    milestoneId: milestoneId,
    escrowId: escrowId ?? this.escrowId,
    escrowMilestoneId: escrowMilestoneId ?? this.escrowMilestoneId,
    phase: phase ?? this.phase,
    blockReason: blockReason ?? this.blockReason,
    releasedAmount: releasedAmount ?? this.releasedAmount,
    serverTimestamp: serverTimestamp ?? this.serverTimestamp,
    message: message ?? this.message,
    code: code ?? this.code,
  );
}
