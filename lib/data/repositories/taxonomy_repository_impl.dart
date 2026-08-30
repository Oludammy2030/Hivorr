import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/mappers/industry_mapper.dart';
import 'package:hivorr/data/mappers/profession_mapper.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// Default implementation composing remote + local (cache) datasources.
///
/// Reads are cache-first: a local hit avoids the network; a miss fetches the
/// remote result and writes it back to the local seam. All errors cross the
/// boundary as typed [ApiException]s. No business decisions are made here
/// (EP-02-07 plan §5.2, §5.5).
class TaxonomyRepositoryImpl implements TaxonomyRepository {
  /// Creates the repository from its remote and local datasources.
  TaxonomyRepositoryImpl({required this.remote, required this.local});

  /// The remote (Supabase) datasource.
  final TaxonomyRemoteDataSource remote;

  /// The local (cache) datasource.
  final TaxonomyLocalDataSource local;

  @override
  Future<List<Industry>> getIndustries() async {
    final List<IndustryDto>? cached = await local.getIndustries();
    if (cached != null) {
      return cached.map(IndustryMapper.toEntity).toList();
    }
    final List<IndustryDto> fetched = await remote.listIndustries();
    await local.saveIndustries(fetched);
    return fetched.map(IndustryMapper.toEntity).toList();
  }

  @override
  Future<List<Profession>> getProfessions({String? industryId}) async {
    final List<ProfessionDto>? cached = await local.getProfessions(
      industryId ?? _allProfessionsKey,
    );
    if (cached != null) {
      return cached.map(ProfessionMapper.toEntity).toList();
    }
    final List<ProfessionDto> fetched = await remote.listProfessions(
      industryId: industryId,
    );
    await local.saveProfessions(industryId ?? _allProfessionsKey, fetched);
    return fetched.map(ProfessionMapper.toEntity).toList();
  }

  @override
  void invalidateTaxonomy() => local.invalidateTaxonomy();

  /// Sentinel key grouping professions fetched without an industry filter
  /// (used to build the hierarchy tree in one RPC call).
  static const String _allProfessionsKey = '__all__';
}
