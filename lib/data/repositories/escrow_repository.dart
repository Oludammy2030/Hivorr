import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';

/// Abstract contract for escrow data operations (EP-02-14 §5.3).
///
/// Depends only on domain entities and value objects — never on concrete
/// backend types — so business systems and UI consume this interface rather
/// than a Supabase implementation (ARCHITECTURE.md / EP-01-08 §5.6).
///
/// Reads are live via `financial_escrow_get`; every write is staged behind the
/// `escrowWriteViaProxyEnabled` seam and surfaces
/// [EscrowWriteUnavailableException] guidance when the seam is off. This
/// repository **never** writes `financial_escrow` / `financial_escrow_milestones`
/// directly (AGENT.md Rule 4, EP-02-14 §8).
abstract class EscrowRepository {
  /// Whether the Edge Function proxy write seam is active (read once).
  bool get writeAvailable;

  /// Fetches a single escrow plus its milestones (and transactions).
  Future<EscrowDetail> getById(String id);

  /// Fetches escrow headers for the known escrow representatives of
  /// [projectId].
  ///
  /// The frozen `financial_escrow_get` RPC has no project filter, so project
  /// membership is resolved by the caller and enumerated via [escrowIds]
  /// (EP-02-14 plan §3 deviation).
  Future<List<Escrow>> getByProject({
    required String projectId,
    required List<String> escrowIds,
  });

  /// Creates an escrow via the write seam.
  ///
  /// Pre-validates the milestone-sum invariant
  /// (`sum(milestones) == totalAmount`, tolerance `0.01`) before any write
  /// attempt and throws `PLT003 validation` on mismatch (fail-fast, EP-02-14
  /// §5.3). When the seam is off the write throws
  /// [EscrowWriteUnavailableException]; the proxy path re-reads the created
  /// escrow to confirm server state.
  Future<EscrowDetail> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  });

  /// Marks a milestone complete (releasing its funds) via the write seam.
  ///
  /// Maps to `financial_escrow_milestone_complete(p_milestone_id)`. Returns
  /// the re-read [EscrowDetail] after a proxy success.
  Future<EscrowDetail> completeMilestone({
    required String escrowId,
    required String milestoneId,
  });

  /// Releases a single milestone's funds via the write seam.
  ///
  /// Per-milestone release is `financial_escrow_milestone_complete`. Returns
  /// the re-read [EscrowDetail] after a proxy success.
  Future<EscrowDetail> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  });

  /// Releases all remaining held funds (final release) via the write seam.
  ///
  /// Maps to `financial_escrow_release(p_escrow_id)`. Returns the re-read
  /// [EscrowDetail] after a proxy success.
  Future<EscrowDetail> releaseFinal({required String escrowId});

  /// Refunds remaining held funds to the payer via the write seam.
  ///
  /// Maps to `financial_escrow_refund(p_escrow_id)`; [reason] is proxy-only
  /// guidance. Returns the re-read [EscrowDetail] after a proxy success.
  Future<EscrowDetail> refundEscrow({
    required String escrowId,
    required String reason,
  });
}