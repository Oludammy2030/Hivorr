import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// Controllable in-memory fake of [TaxonomyRemoteDataSource] for unit tests.
///
/// Returns the configured [industries] / [professions] list and records
/// invocation counts so tests can assert cache-first behavior (no remote call
/// on a cache hit). When [throwError] is set, every call throws it.
class FakeTaxonomyRemoteDataSource extends TaxonomyRemoteDataSource {
  List<IndustryDto> industries = <IndustryDto>[];
  List<ProfessionDto> professions = <ProfessionDto>[];
  ApiException? throwError;

  int listIndustriesCallCount = 0;
  int listProfessionsCallCount = 0;

  /// Last `includeInactive` argument seen by [listIndustries].
  bool lastListIndustriesIncludeInactive = false;

  /// Last `industryId` / `includeInactive` args seen by [listProfessions].
  String? lastListProfessionsIndustryId;
  bool lastListProfessionsIncludeInactive = false;

  @override
  Future<List<IndustryDto>> listIndustries({
    bool includeInactive = false,
  }) async {
    listIndustriesCallCount++;
    lastListIndustriesIncludeInactive = includeInactive;
    if (throwError != null) {
      throw throwError!;
    }
    return List<IndustryDto>.of(industries);
  }

  @override
  Future<List<ProfessionDto>> listProfessions({
    String? industryId,
    bool includeInactive = false,
  }) async {
    listProfessionsCallCount++;
    lastListProfessionsIndustryId = industryId;
    lastListProfessionsIncludeInactive = includeInactive;
    if (throwError != null) {
      throw throwError!;
    }
    if (industryId == null) {
      return List<ProfessionDto>.of(professions);
    }
    return professions
        .where((ProfessionDto p) => p.industryId == industryId)
        .toList();
  }
}

/// Controllable in-memory fake of [TaxonomyRepository] for engine/widget tests.
class FakeTaxonomyRepository extends TaxonomyRepository {
  FakeTaxonomyRepository({
    List<Industry>? industries,
    List<Profession>? professions,
  })  : industries = industries ?? <Industry>[],
        professions = professions ?? <Profession>[];

  List<Industry> industries;
  List<Profession> professions;
  ApiException? throwError;
  int getIndustriesCallCount = 0;
  int getProfessionsCallCount = 0;

  @override
  Future<List<Industry>> getIndustries() async {
    getIndustriesCallCount++;
    if (throwError != null) {
      throw throwError!;
    }
    return List<Industry>.of(industries);
  }

  @override
  Future<List<Profession>> getProfessions({String? industryId}) async {
    getProfessionsCallCount++;
    if (throwError != null) {
      throw throwError!;
    }
    if (industryId == null) {
      return List<Profession>.of(professions);
    }
    return professions
        .where((Profession p) => p.industryId == industryId)
        .toList();
  }

  @override
  void invalidateTaxonomy() {
    // no-op for tests
  }
}
