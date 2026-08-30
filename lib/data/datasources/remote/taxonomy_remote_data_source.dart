import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';

/// Abstract contract for the remote (Supabase) side of taxonomy data.
///
/// Implementations must access the backend only through the EP-01-07
/// `BaseApiService` channel — never constructing clients directly and never
/// importing write RPCs (EP-02-07 plan §5.3, §12). Both reads are public
/// `STABLE` RPCs granted to `anon, authenticated, service_role`.
abstract class TaxonomyRemoteDataSource {
  /// Lists industries in `sort_order ASC`, active-only unless
  /// [includeInactive] is `true` (admin views only).
  Future<List<IndustryDto>> listIndustries({bool includeInactive = false});

  /// Lists professions in `sort_order ASC`, optionally scoped to [industryId].
  /// A `null` [industryId] returns all professions (used for the hierarchy
  /// tree). Active-only unless [includeInactive] is `true`.
  Future<List<ProfessionDto>> listProfessions({
    String? industryId,
    bool includeInactive = false,
  });
}
