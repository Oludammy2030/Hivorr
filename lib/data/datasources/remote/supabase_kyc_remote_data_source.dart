import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/kyc_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';

/// Supabase-backed implementation of [KycRemoteDataSource].
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). Every read goes through the KYC RPCs — never
/// direct table writes. Status mutation is server-authoritative (`AGENT.md`
/// Rule 4).
class SupabaseKycRemoteDataSource extends BaseApiService
    implements KycRemoteDataSource {
  /// Creates the datasource from the single EP-01-07 API channel.
  SupabaseKycRemoteDataSource({
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
  Future<KycLevelDto> getKycLevel() => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'verification_kyc_level_get',
        );
        final Map<String, dynamic> data =
            VerificationEnvelopeParser.unwrap(response);
        return KycLevelDto.fromJson(data);
      });

  @override
  Future<KycLimitsDto> getLimits() => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'verification_limits_get',
        );
        final Map<String, dynamic> data =
            VerificationEnvelopeParser.unwrap(response);
        return KycLimitsDto.fromJson(data);
      });

  @override
  Future<VerificationStatusDto> getStatus({String? entityId}) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'verification_status_get',
          params: entityId == null
              ? null
              : <String, dynamic>{'p_entity_id': entityId},
        );
        final Map<String, dynamic> data =
            VerificationEnvelopeParser.unwrap(response);
        return VerificationStatusDto.fromJson(data);
      });
}
