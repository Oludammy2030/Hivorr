// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/trade_verification_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';

/// Supabase-backed implementation of [TradeVerificationRemoteDataSource]
/// (EP-02-11 §5.2).
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). Every read/write goes through the verification
/// RPCs (`verification_submit` / `verification_status_get`) — never direct
/// table writes. Status mutation is server-authoritative (`AGENT.md` Rule 4);
/// the client never writes `entity_professions.trade_verification_status`.
class SupabaseTradeVerificationRemoteDataSource extends BaseApiService
    implements TradeVerificationRemoteDataSource {
  /// Creates the datasource from the single EP-01-07 API channel.
  SupabaseTradeVerificationRemoteDataSource({
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
  Future<VerificationSubmissionDto> submit({
    required String credentialId,
    String submissionType = 'trade_proof',
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'verification_submit',
          params: <String, dynamic>{
            'p_credential_id': credentialId,
            'p_submission_type': submissionType,
          },
        );
        final Map<String, dynamic> data =
            VerificationEnvelopeParser.unwrap(response);
        return VerificationSubmissionDto.fromJson(data);
      });

  @override
  Future<VerificationStatusDto> getStatus({String? entityId}) =>
      _guard(() async {
        final Map<String, dynamic> params = <String, dynamic>{};
        if (entityId != null && entityId.isNotEmpty) {
          params['p_entity_id'] = entityId;
        }
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'verification_status_get',
          params: params,
        );
        final Map<String, dynamic> data =
            VerificationEnvelopeParser.unwrap(response);
        return VerificationStatusDto.fromJson(data);
      });
}
