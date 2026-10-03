import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/service_contract_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/service_contract_remote_data_source.dart';
import 'package:hivorr/data/models/contract_envelopes_dto.dart';

/// Supabase-backed implementation of [ServiceContractRemoteDataSource]
/// (EP-03-10 §11).
///
/// Wraps the eight contract RPCs via `supabase.rpc(...)` and unwraps the
/// standard `{success, code, message, data}` envelope with
/// [ServiceContractEnvelopeParser]. Mirrors
/// `SupabaseHiresRemoteDataSource` (`_guard(mapDataException)` + `p_*`
/// params). This class never writes contract tables directly and never
/// references service-role-only transitions.
class SupabaseServiceContractRemoteDataSource extends BaseApiService
    implements ServiceContractRemoteDataSource {
  SupabaseServiceContractRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<ContractOfferEnvelopeDto> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<Map<String, dynamic>> milestones,
    String? offerExpiresAt,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_contract_offer',
          params: <String, dynamic>{
            'p_service_listing_id': serviceListingId,
            'p_total_amount': totalAmount,
            'p_currency_code': currencyCode,
            'p_milestones': milestones,
            'p_offer_expires_at': ?offerExpiresAt,
          },
        );
    return ContractOfferEnvelopeDto.fromJson(
      ServiceContractEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<Map<String, dynamic>> acceptContract(String contractId) => _guard(
    () async {
      final Map<String, dynamic> response = await supabase
          .rpc<Map<String, dynamic>>(
            'service_contract_accept',
            params: <String, dynamic>{'p_contract_id': contractId},
          );
      return ServiceContractEnvelopeParser.unwrap(response);
    },
  );

  @override
  Future<Map<String, dynamic>> cancelContract(
    String contractId, {
    String? reason,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_contract_cancel',
          params: <String, dynamic>{
            'p_contract_id': contractId,
            'p_reason': ?reason,
          },
        );
    return ServiceContractEnvelopeParser.unwrap(response);
  });

  @override
  Future<Map<String, dynamic>> completeMilestone({
    required String milestoneId,
    String? evidencePath,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_contract_complete_milestone',
          params: <String, dynamic>{
            'p_milestone_id': milestoneId,
            'p_evidence_path': ?evidencePath,
          },
        );
    return ServiceContractEnvelopeParser.unwrap(response);
  });

  @override
  Future<Map<String, dynamic>> verifyMilestone({
    required String milestoneId,
    String action = 'verified',
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_contract_verify_milestone',
          params: <String, dynamic>{
            'p_milestone_id': milestoneId,
            'p_action': action,
          },
        );
    return ServiceContractEnvelopeParser.unwrap(response);
  });

  @override
  Future<Map<String, dynamic>> closeContract(String contractId) => _guard(
    () async {
      final Map<String, dynamic> response = await supabase
          .rpc<Map<String, dynamic>>(
            'service_contract_close',
            params: <String, dynamic>{'p_contract_id': contractId},
          );
      return ServiceContractEnvelopeParser.unwrap(response);
    },
  );

  @override
  Future<ContractDetailEnvelopeDto> getContract(String contractId) => _guard(
    () async {
      final Map<String, dynamic> response = await supabase
          .rpc<Map<String, dynamic>>(
            'service_contract_get',
            params: <String, dynamic>{'p_contract_id': contractId},
          );
      return ContractDetailEnvelopeDto.fromJson(
        ServiceContractEnvelopeParser.unwrap(response),
      );
    },
  );

  @override
  Future<ContractListEnvelopeDto> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_contract_list_mine',
          params: <String, dynamic>{
            'p_status': ?status,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return ContractListEnvelopeDto.fromJson(
      ServiceContractEnvelopeParser.unwrap(response),
    );
  });
}
