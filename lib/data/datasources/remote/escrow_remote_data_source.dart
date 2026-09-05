import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';

/// Abstract contract for the remote (Supabase) side of escrow data (EP-02-14).
///
/// **Read** methods are live today via the authenticated, payer/payee self-
/// scoped `financial_escrow_get` RPC
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1111-1147`,
/// granted to `authenticated` at `1683`).
///
/// **Write** methods are a seam, never a direct RPC: the five escrow write
/// RPCs are granted `service_role`-only (`1690-1694`), so an authenticated
/// client calling them receives `403 PLT002`. All writes route through the
/// Edge Function proxy (`financial-escrow-proxy`, deployed by EP-02-18) and
/// are gated by [writeViaProxy]. When `false`, every write throws
/// [EscrowWriteUnavailableException] with support-team guidance — never a
/// silent no-op. When `true`, the proxy branch is invoked (the concrete HTTP
/// path is EP-02-18's contract).
abstract class EscrowRemoteDataSource {
  /// Whether the Edge Function proxy write seam is active.
  ///
  /// Backed by the `escrowWriteViaProxyEnabled` feature flag (default `false`
  /// in all environments). Providers read this once at construction.
  bool get writeViaProxy;

  /// Fetches a single escrow plus its milestones.
  ///
  /// Backed by `financial_escrow_get(p_escrow_id)`. Throws `PLT004` when the
  /// actor is not a party to the escrow.
  Future<EscrowDetailDto> getById(String id);

  /// Fetches escrow headers for a set of known escrow ids.
  ///
  /// The frozen `financial_escrow_get` RPC filters only by `p_escrow_id` —
  /// there is no project filter. Project↔escrow membership is resolved by the
  /// caller, and [escrowIds] enumerates the known representatives (EP-02-14
  /// plan §3 deviation: `getByProject` enumerates known ids).
  Future<List<EscrowDto>> getByProject(List<String> escrowIds);

  /// Creates an escrow through the write seam, returning the created escrow id.
  ///
  /// Proxy payload maps to `financial_escrow_create`
  /// (`p_payer_entity_id`, `p_payee_entity_id`, `p_currency_code`,
  /// `p_total_amount`, `p_milestones` jsonb array of `EscrowMilestoneInput`);
  /// the RPC response carries `{escrow_id, total_amount, currency_code}`.
  /// Throws [EscrowWriteUnavailableException] when [writeViaProxy] is false.
  Future<String> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  });

  /// Funds an escrow through the write seam.
  ///
  /// Maps to `financial_escrow_fund(p_escrow_id)`. Gated by [writeViaProxy].
  Future<void> fundEscrow({required String escrowId});

  /// Marks a milestone complete (and releases its funds) via the write seam.
  ///
  /// Maps to `financial_escrow_milestone_complete(p_milestone_id)`
  /// (`milestone_id` in the proxy payload). Gated by [writeViaProxy].
  Future<void> completeMilestone({
    required String escrowId,
    required String milestoneId,
  });

  /// Releases a single milestone's funds via the write seam.
  ///
  /// Per-milestone release is achieved through
  /// `financial_escrow_milestone_complete(p_milestone_id)` — the frozen server
  /// releases a completed milestone's funds immediately. Gated by
  /// [writeViaProxy].
  Future<void> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  });

  /// Releases all remaining held funds via the write seam.
  ///
  /// Maps to `financial_escrow_release(p_escrow_id)` — the escrow-level final
  /// release (`905-967`). Gated by [writeViaProxy].
  Future<void> releaseFinal({required String escrowId});

  /// Refunds all remaining held funds to the payer via the write seam.
  ///
  /// Maps to `financial_escrow_refund(p_escrow_id)` (`969-1025`); [reason] is
  /// carried in the proxy payload only (the frozen RPC does not take one).
  /// Gated by [writeViaProxy].
  Future<void> refundEscrow({
    required String escrowId,
    required String reason,
  });
}