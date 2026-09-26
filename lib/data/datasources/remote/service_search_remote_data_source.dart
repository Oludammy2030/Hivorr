import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/service_search_envelope_parser.dart';
import 'package:hivorr/data/models/service_listing_dto.dart';

/// Abstract contract for the remote (Supabase) side of ranked search.
///
/// Implementations must access the backend **only** through the EP-01-07
/// [BaseApiService] channel (`supabase.rpc('service_ranking_search')`) — never
/// direct table `SELECT`. Ordering is always server-decided (`AGENT.md:7`).
abstract class ServiceSearchRemoteDataSource {
  /// Ranked search using `service_ranking_search`
  /// (`20260927090001_platform_config_and_ranking.sql:233`).
  ///
  /// Returns a page `{items, has_more, next_cursor, weights_version}` in RPC
  /// order (no resort).
  Future<ServiceSearchPageDto> rankingSearch({
    String? professionId,
    String? query,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? cursor,
    int limit = 20,
  });
}

/// Supabase-backed implementation of [ServiceSearchRemoteDataSource].
///
/// Single RPC seam per the approved plan §7.4; mirrors
/// `SupabaseTaxonomyRemoteDataSource:17` `_guard(mapDataException)` pattern.
class SupabaseServiceSearchRemoteDataSource extends BaseApiService
    implements ServiceSearchRemoteDataSource {
  SupabaseServiceSearchRemoteDataSource({
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
  Future<ServiceSearchPageDto> rankingSearch({
    String? professionId,
    String? query,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? cursor,
    int limit = 20,
  }) =>
      _guard(() async {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_limit': limit,
        };
        if (professionId != null && professionId.isNotEmpty) {
          params['p_profession_id'] = professionId;
        }
        if (query != null) {
          params['p_query'] = query;
        }
        if (filters != null && filters.isNotEmpty) {
          params['p_filters'] = filters;
        }
        if (cursor != null) {
          params['p_cursor'] = cursor;
        }

        final Map<String, dynamic> envelope =
            await supabase.rpc<Map<String, dynamic>>(
          'service_ranking_search',
          params: params,
        );

        final Map<String, dynamic> data =
            ServiceSearchEnvelopeParser.unwrapData(envelope);
        return ServiceSearchPageDto.fromJson(data);
      });
}
