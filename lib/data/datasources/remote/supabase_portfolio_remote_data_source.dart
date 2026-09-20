import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/portfolio_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/portfolio_remote_data_source.dart';
import 'package:hivorr/data/models/public_profile_dto.dart';

/// Supabase-backed implementation of [PortfolioRemoteDataSource] (EP-02-19).
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). The sole read goes through the read-only
/// `portfolio_public_profile_get` SECURITY DEFINER RPC — never direct table
/// SELECT (EP-02-19 plan §5.3, §8).
class SupabasePortfolioRemoteDataSource extends BaseApiService
    implements PortfolioRemoteDataSource {
  SupabasePortfolioRemoteDataSource({
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
  Future<PublicProfileDto> fetchPublicProfile(String entityId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'portfolio_public_profile_get',
              params: <String, dynamic>{'p_entity_id': entityId},
            );
        final Map<String, dynamic> data = PortfolioEnvelopeParser.unwrap(
          response,
        );
        return PublicProfileDto.fromJson(data);
      });
}
