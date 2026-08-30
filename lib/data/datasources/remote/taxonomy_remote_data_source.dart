import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Abstract contract for the remote (Supabase) side of taxonomy data.
///
/// Implementations must access the backend only through the EP-01-07
/// [BaseApiService] channel and the read-only `taxonomy_*_list` RPCs — never
/// directly reading the `industries`/`professions` tables (EP-01-08 §5.4,
/// EP-02-07 plan §5.2).
abstract class TaxonomyRemoteDataSource {
  /// Returns all industries, optionally including inactive ones.
  ///
  /// Backed by `taxonomy_industries_list`. Results are already ordered
  /// `sort_order ASC` by the server.
  Future<List<IndustryDto>> getIndustries({
    bool includeInactive = false,
  });

  /// Returns all professions, optionally scoped to [industryId].
  ///
  /// Backed by `taxonomy_professions_list`. When [industryId] is `null`, all
  /// professions are returned; otherwise only those belonging to that industry.
  /// Results are ordered `sort_order ASC` by the server.
  Future<List<ProfessionDto>> getProfessions({
    String? industryId,
    bool includeInactive = false,
  });
}
