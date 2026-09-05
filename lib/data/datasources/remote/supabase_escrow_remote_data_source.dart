import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/escrow_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/datasources/remote/financial_envelope_parser.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';

/// Supabase-backed implementation of [EscrowRemoteDataSource].
///
/// Reads go through the authenticated, self-scoped `financial_escrow_get`
/// RPC using the standard financial envelope
/// (`{success, code PLT000, data:{escrow, milestones}}`) via
/// [FinancialEnvelopeParser]. All writes are staged behind the
/// [EscrowRemoteDataSource.writeViaProxy] seam:
/// - `writeViaProxy == false` → throws [EscrowWriteUnavailableException] with
///   support-team guidance (the current production behavior).
/// - `writeViaProxy == true`  → the Edge Function proxy branch is invoked. The
///   concrete `supabase.functions.invoke('financial-escrow-proxy', ...)` HTTP
///   path is owned by EP-02-18; until it ships this branch throws
///   [UnimplementedError] — **never** a direct `supabase.rpc` call to a
///   `service_role`-only write RPC (`1690-1694`).
class SupabaseEscrowRemoteDataSource extends BaseApiService
    implements EscrowRemoteDataSource {
  SupabaseEscrowRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
    this._writeViaProxy = false,
  });

  final bool _writeViaProxy;

  @override
  bool get writeViaProxy => _writeViaProxy;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<EscrowDetailDto> getById(String id) => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'financial_escrow_get',
          params: <String, dynamic>{'p_escrow_id': id},
        );
        final Map<String, dynamic> data =
            FinancialEnvelopeParser.unwrap(response);
        return EscrowDetailDto.fromJson(data);
      });

  @override
  Future<List<EscrowDto>> getByProject(List<String> escrowIds) =>
      _guard(() async {
        final List<EscrowDto> results = <EscrowDto>[];
        for (final String escrowId in escrowIds) {
          final EscrowDetailDto detail = await getById(escrowId);
          results.add(detail.escrow);
        }
        return results;
      });

  /// The documented write seam guard (EP-02-14 §5.2 / EP-02-18 handoff).
  ///
  /// Never silent: when the proxy flag is off the caller receives explicit
  /// support-team guidance; when on, the as-yet-undeployed proxy branch is
  /// invoked (contract payloads are documented per method below).
  Never _writeSeamUnavailable(String action) {
    if (!_writeViaProxy) {
      throw const EscrowWriteUnavailableException();
    }
    throw UnimplementedError(
      'Edge Function proxy deployment pending EP-02-18 ($action).',
    );
  }

  @override
  Future<String> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    // Proxy payload → financial_escrow_create(p_payer_entity_id,
    // p_payee_entity_id, p_currency_code, p_total_amount, p_milestones jsonb);
    // response returns {escrow_id, total_amount, currency_code}.
    _writeSeamUnavailable('escrow_create');
  }

  @override
  Future<void> fundEscrow({required String escrowId}) async {
    // Proxy payload → financial_escrow_fund(p_escrow_id).
    _writeSeamUnavailable('escrow_fund');
  }

  @override
  Future<void> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    // Proxy payload {milestone_id} → financial_escrow_milestone_complete.
    // escrowId is used by the repository for the post-success re-read.
    _writeSeamUnavailable('escrow_milestone_complete');
  }

  @override
  Future<void> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    // Per-milestone release is financial_escrow_milestone_complete
    // ({milestone_id}); the frozen server releases a completed milestone's
    // funds immediately. escrowId is used for the post-success re-read.
    _writeSeamUnavailable('escrow_milestone_release');
  }

  @override
  Future<void> releaseFinal({required String escrowId}) async {
    // Proxy payload {escrow_id} → financial_escrow_release(p_escrow_id).
    _writeSeamUnavailable('escrow_release_final');
  }

  @override
  Future<void> refundEscrow({
    required String escrowId,
    required String reason,
  }) async {
    // Proxy payload {escrow_id, reason} → financial_escrow_refund(p_escrow_id);
    // `reason` is client guidance only (the frozen RPC takes no reason).
    _writeSeamUnavailable('escrow_refund');
  }
}