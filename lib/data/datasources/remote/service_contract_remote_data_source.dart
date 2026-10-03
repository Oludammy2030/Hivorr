import 'package:hivorr/data/models/contract_envelopes_dto.dart';

/// Contract for service contract transport (EP-03-10 §11).
///
/// Wraps exactly the eight client-callable contract RPCs granted to
/// `authenticated`
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`):
/// `service_contract_offer`, `service_contract_accept`,
/// `service_contract_cancel`, `service_contract_complete_milestone`,
/// `service_contract_verify_milestone`, `service_contract_close`,
/// `service_contract_get`, `service_contract_list_mine`.
///
/// Contract tables (`service_contracts` / `contract_milestones` /
/// `contract_events`) are **never** written directly — all state changes flow
/// through these RPCs per `AGENT.md` Rule 4.
abstract class ServiceContractRemoteDataSource {
  /// Creates an `offered` contract with its `pending` milestones
  /// (`service_contract_offer`, VOLATILE).
  Future<ContractOfferEnvelopeDto> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<Map<String, dynamic>> milestones,
    String? offerExpiresAt,
  });

  /// Accepts an `offered` contract as the professional
  /// (`service_contract_accept`, VOLATILE).
  Future<Map<String, dynamic>> acceptContract(String contractId);

  /// Cancels an `offered` contract (either participant)
  /// (`service_contract_cancel`, VOLATILE).
  Future<Map<String, dynamic>> cancelContract(
    String contractId, {
    String? reason,
  });

  /// Marks a `pending` milestone `completed` with evidence
  /// (`service_contract_complete_milestone`, VOLATILE).
  Future<Map<String, dynamic>> completeMilestone({
    required String milestoneId,
    String? evidencePath,
  });

  /// Verifies a `completed` milestone (client) or requests revision
  /// (`service_contract_verify_milestone`, VOLATILE).
  Future<Map<String, dynamic>> verifyMilestone({
    required String milestoneId,
    String action = 'verified',
  });

  /// Closes an `active`/`completed` contract once all milestones are verified
  /// (`service_contract_close`, VOLATILE).
  Future<Map<String, dynamic>> closeContract(String contractId);

  /// Fetches a contract with `milestones[]` + `events[]` in one RPC
  /// (`service_contract_get`, STABLE; participant-scoped, `PLT004` oracle).
  Future<ContractDetailEnvelopeDto> getContract(String contractId);

  /// Lists the caller's contracts with keyset pagination
  /// (`service_contract_list_mine`, STABLE).
  Future<ContractListEnvelopeDto> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  });
}
