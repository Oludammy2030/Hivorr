import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Supabase-backed implementation of [TaxonomyRemoteDataSource].
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). Calls only the two public `STABLE` read RPCs
/// (`taxonomy_industries_list`, `taxonomy_professions_list`), unwraps the
/// standardized `{success, code, message, data}` envelope, and normalizes any
/// transport/PostgREST/`PLT*` failure to an [ApiException] before it crosses
/// the repository boundary (EP-02-07 plan §5.3, §12).
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

  /// Unwraps the `data` array from the standardized RPC envelope, mapping each
  /// row via [parse]. A `success:false` envelope (never expected on these
  /// STABLE reads) is treated as a server failure.
  List<T> _unwrap<T>(Map<String, dynamic> envelope, T Function(dynamic) parse) {
    if (envelope['success'] == false) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'A server error occurred.',
        code: 'PLT999',
      );
    }
    final Object? raw = envelope['data'];
    if (raw is! List) {
      throw const ApiException(
        kind: ApiExceptionKind.unknown,
        message: 'An unexpected data error occurred.',
      );
    }
    return raw.map(parse).toList();
  }

  @override
  Future<List<IndustryDto>> listIndustries({
    bool includeInactive = false,
  }) => _guard(() async {
    final Map<String, dynamic> envelope =
        await supabase.rpc<Map<String, dynamic>>(
          'taxonomy_industries_list',
          params: <String, dynamic>{'p_include_inactive': includeInactive},
        );
    return _unwrap<IndustryDto>(
      envelope,
      (dynamic row) => IndustryDto.fromJson(row as Map<String, dynamic>),
    );
  });

  @override
  Future<List<ProfessionDto>> listProfessions({
    String? industryId,
    bool includeInactive = false,
  }) => _guard(() async {
    final Map<String, dynamic> envelope =
        await supabase.rpc<Map<String, dynamic>>(
          'taxonomy_professions_list',
          params: <String, dynamic>{
            'p_industry_id': industryId,
            'p_include_inactive': includeInactive,
          },
        );
    return _unwrap<ProfessionDto>(
      envelope,
      (dynamic row) => ProfessionDto.fromJson(row as Map<String, dynamic>),
    );
  });
}
