import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/models/profession_dto.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// Shared, dependency-free fakes for the taxonomy data slice (EP-02-07).
///
/// Implements remote/repository abstractions with controllable in-memory state
/// so repositories/providers/engines can be exercised without a live backend.

/// Number of industries / professions mirrored from the EP-02-01 seed for
/// representative test fixtures.
const List<Map<String, dynamic>> seedIndustryRows = <Map<String, dynamic>>[
  <String, dynamic>{'id': 'ind-legal', 'slug': 'legal', 'name': 'Legal', 'description': 'Legal services', 'is_active': true, 'sort_order': 10},
  <String, dynamic>{'id': 'ind-tech', 'slug': 'technology', 'name': 'Technology', 'description': 'Software and IT', 'is_active': true, 'sort_order': 20},
  <String, dynamic>{'id': 'ind-health', 'slug': 'healthcare', 'name': 'Healthcare', 'description': 'Medical', 'is_active': true, 'sort_order': 30},
];

const List<Map<String, dynamic>> seedTechProfessionRows = <Map<String, dynamic>>[
  <String, dynamic>{'id': 'prof-sw', 'industry_id': 'ind-tech', 'slug': 'software-engineer', 'name': 'Software Engineer', 'description': 'Build software', 'is_active': true, 'sort_order': 10},
  <String, dynamic>{'id': 'prof-web', 'industry_id': 'ind-tech', 'slug': 'web-developer', 'name': 'Web Developer', 'description': 'Build web apps', 'is_active': true, 'sort_order': 20},
  <String, dynamic>{'id': 'prof-mobile', 'industry_id': 'ind-tech', 'slug': 'mobile-developer', 'name': 'Mobile Developer', 'description': 'Build mobile apps', 'is_active': true, 'sort_order': 30},
];

/// Controllable [TaxonomyRemoteDataSource] for unit tests.
class FakeTaxonomyRemoteDataSource implements TaxonomyRemoteDataSource {
  /// Industries returned by [getIndustries].
  List<IndustryDto> industries =
      seedIndustryRows.map(IndustryDto.fromJson).toList();

  /// Professions returned by [getProfessions].
  List<ProfessionDto> professions =
      seedTechProfessionRows.map(ProfessionDto.fromJson).toList();

  /// When non-null, [getIndustries] throws this.
  ApiException? nextError;

  /// Number of [getIndustries] calls (cache-first assertions).
  int getIndustriesCallCount = 0;

  /// Number of [getProfessions] calls (cache-first assertions).
  int getProfessionsCallCount = 0;

  @override
  Future<List<IndustryDto>> getIndustries({
    bool includeInactive = false,
  }) async {
    getIndustriesCallCount++;
    if (nextError != null) {
      throw nextError!;
    }
    return List<IndustryDto>.from(industries);
  }

  @override
  Future<List<ProfessionDto>> getProfessions({
    String? industryId,
    bool includeInactive = false,
  }) async {
    getProfessionsCallCount++;
    if (nextError != null) {
      throw nextError!;
    }
    if (industryId == null) {
      return List<ProfessionDto>.from(professions);
    }
    return professions
        .where((ProfessionDto p) => p.industryId == industryId)
        .toList();
  }
}

/// In-memory fake of [TaxonomyRepository] for widget/provider tests, so the
/// browser can be rendered without any datasource wiring.
class FakeTaxonomyRepository implements TaxonomyRepository {
  FakeTaxonomyRepository({
    List<Industry>? industries,
    Map<String, List<Profession>>? professionsByIndustry,
  })  : _industries = industries ?? <Industry>[],
        _professionsByIndustry = professionsByIndustry ?? <String, List<Profession>>{};

  final List<Industry> _industries;
  final Map<String, List<Profession>> _professionsByIndustry;
  int getIndustriesCallCount = 0;
  int invalidateCallCount = 0;

  @override
  Future<List<Industry>> getIndustries({bool includeInactive = false}) async {
    getIndustriesCallCount++;
    return _industries
        .where((Industry i) => includeInactive || i.isActive)
        .toList();
  }

  @override
  Future<List<Profession>> getProfessions({
    String? industryId,
    bool includeInactive = false,
  }) async {
    if (industryId == null) {
      return _professionsByIndustry.values
          .expand((List<Profession> p) => p)
          .where((Profession p) => includeInactive || p.isActive)
          .toList();
    }
    return (_professionsByIndustry[industryId] ?? <Profession>[])
        .where((Profession p) => includeInactive || p.isActive)
        .toList();
  }

  @override
  Future<void> invalidate() async {
    invalidateCallCount++;
  }
}
