import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/mappers/industry_mapper.dart';
import 'package:hivorr/data/mappers/profession_mapper.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// Default implementation composing remote + local datasources.
///
/// Reads are cache-first (local hit → return, miss → remote fetch → save),
/// so a warm start issues zero RPCs (EP-02-07 plan §5.4, §13). Client-side
/// `activeOnly` filtering is applied after mapping so cached data that already
/// contains only active rows still respects the flag.
class TaxonomyRepositoryImpl implements TaxonomyRepository {
  /// Creates the repository from its two datasource dependencies.
  TaxonomyRepositoryImpl({
    required this.remote,
    required this.local,
  });

  /// The remote (Supabase) datasource.
  final TaxonomyRemoteDataSource remote;

  /// The local (cache) datasource.
  final TaxonomyLocalDataSource local;

  @override
  Future<List<Industry>> getIndustries({
    bool includeInactive = false,
  }) async {
    final List<IndustryDto>? cached = await local.getIndustries();
    if (cached != null && cached.isNotEmpty) {
      return _mapIndustries(cached, includeInactive);
    }
    final List<IndustryDto> fetched = await remote.getIndustries(
      includeInactive: includeInactive,
    );
    await local.saveIndustries(fetched);
    return _mapIndustries(fetched, includeInactive);
  }

  @override
  Future<List<Profession>> getProfessions({
    String? industryId,
    bool includeInactive = false,
  }) async {
    if (industryId != null) {
      final List<ProfessionDto>? cached = await local.getProfessions(
        industryId,
      );
      if (cached != null) {
        return _mapProfessions(cached, includeInactive);
      }
    }
    final List<ProfessionDto> fetched = await remote.getProfessions(
      industryId: industryId,
      includeInactive: includeInactive,
    );
    if (industryId != null) {
      await local.saveProfessions(industryId, fetched);
    }
    return _mapProfessions(fetched, includeInactive);
  }

  @override
  Future<void> invalidate() => local.invalidate();

  List<Industry> _mapIndustries(
    List<IndustryDto> dtos,
    bool includeInactive,
  ) {
    return dtos
        .map(IndustryMapper.toEntity)
        .where((Industry i) => includeInactive || i.isActive)
        .toList(growable: false);
  }

  List<Profession> _mapProfessions(
    List<ProfessionDto> dtos,
    bool includeInactive,
  ) {
    return dtos
        .map(ProfessionMapper.toEntity)
        .where((Profession p) => includeInactive || p.isActive)
        .toList(growable: false);
  }
}
