import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Supabase-backed implementation of [TaxonomyRemoteDataSource].
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). All reads go through the read-only RPCs
/// `taxonomy_industries_list` / `taxonomy_professions_list` — never direct
/// table `SELECT` (EP-02-07 plan §5.2, §8). Each RPC returns the standard
/// `{success, code, message, data}` envelope; [TaxonomyEnvelopeParser]
/// validates it before DTO mapping.
class SupabaseTaxonomyRemoteDataSource extends BaseApiService
    implements TaxonomyRemoteDataSource {
  /// Creates the datasource from the single EP-01-07 API channel.
  SupabaseTaxonomyRemoteDataSource({
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
  Future<List<IndustryDto>> getIndustries({
    bool includeInactive = false,
  }) => _guard(() async {
    final Map<String, dynamic> response =
        await supabase.rpc<Map<String, dynamic>>(
      'taxonomy_industries_list',
      params: <String, dynamic>{'p_include_inactive': includeInactive},
    );
    final List<Map<String, dynamic>> rows =
        TaxonomyEnvelopeParser.unwrapData(response);
    return rows.map(IndustryDto.fromJson).toList(growable: false);
  });

  @override
  Future<List<ProfessionDto>> getProfessions({
    String? industryId,
    bool includeInactive = false,
  }) => _guard(() async {
    final Map<String, dynamic> params = <String, dynamic>{
      'p_include_inactive': includeInactive,
    };
    if (industryId != null && industryId.isNotEmpty) {
      params['p_industry_id'] = industryId;
    }
    final Map<String, dynamic> response =
        await supabase.rpc<Map<String, dynamic>>(
      'taxonomy_professions_list',
      params: params,
    );
    final List<Map<String, dynamic>> rows =
        TaxonomyEnvelopeParser.unwrapData(response);
    return rows.map(ProfessionDto.fromJson).toList(growable: false);
  });
}
