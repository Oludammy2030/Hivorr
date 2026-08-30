import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';

import '../../support/fakes/fake_taxonomy.dart';

void main() {
  Industry industry({
    String id = 'ind-tech',
    String slug = 'technology',
    String name = 'Technology',
    int sortOrder = 20,
  }) => Industry(
    id: id,
    slug: slug,
    name: name,
    isActive: true,
    sortOrder: sortOrder,
  );

  Profession profession({
    String id = 'prof-web',
    String industryId = 'ind-tech',
    String name = 'Web Developer',
  }) => Profession(
    id: id,
    industryId: industryId,
    slug: 'web-developer',
    name: name,
    isActive: true,
    sortOrder: 20,
  );

  group('TaxonomyProvider', () {
    test('loadIndustries transitions idle -> loaded and exposes industries',
        () async {
      final repo = FakeTaxonomyRepository(industries: <Industry>[industry()]);
      final provider = TaxonomyProvider(repository: repo);

      expect(provider.state, TaxonomyProviderState.idle);
      await provider.loadIndustries();

      expect(provider.state, TaxonomyProviderState.loaded);
      expect(provider.industries.length, 1);
      expect(provider.error, isNull);
    });

    test('loadProfessions populates professionsByIndustry', () async {
      final repo = FakeTaxonomyRepository(
        industries: <Industry>[industry()],
        professionsByIndustry: <String, List<Profession>>{
          'ind-tech': <Profession>[profession()],
        },
      );
      final provider = TaxonomyProvider(repository: repo);

      await provider.loadIndustries();
      await provider.loadProfessions('ind-tech');

      expect(provider.professionsByIndustry['ind-tech']!.length, 1);
    });

    test('selectIndustry sets selection and resets selectedProfession', () async {
      final repo = FakeTaxonomyRepository(
        industries: <Industry>[industry()],
        professionsByIndustry: <String, List<Profession>>{
          'ind-tech': <Profession>[profession()],
        },
      );
      final provider = TaxonomyProvider(repository: repo);

      await provider.loadIndustries();
      provider.selectIndustry('ind-tech');
      provider.selectProfession(profession());
      expect(provider.selectedIndustry?.id, 'ind-tech');
      expect(provider.selectedProfession, isNotNull);

      provider.selectIndustry('ind-tech');
      expect(provider.selectedProfession, isNull);
    });

    test('professionsForSelectedIndustry returns the scoped list', () async {
      final repo = FakeTaxonomyRepository(
        industries: <Industry>[industry()],
        professionsByIndustry: <String, List<Profession>>{
          'ind-tech': <Profession>[profession()],
        },
      );
      final provider = TaxonomyProvider(repository: repo);

      await provider.loadIndustries();
      await provider.loadProfessions('ind-tech');
      provider.selectIndustry('ind-tech');

      expect(provider.professionsForSelectedIndustry.length, 1);
    });

    test('error state surfaces ApiException', () async {
      final provider = TaxonomyProvider(repository: ThrowingTaxonomyRepository());

      await provider.loadIndustries();

      expect(provider.state, TaxonomyProviderState.error);
      expect(provider.error, isA<ApiException>());
    });
  });
}

/// Repository whose [getIndustries] always throws, for error-path tests.
class ThrowingTaxonomyRepository extends FakeTaxonomyRepository {
  @override
  Future<List<Industry>> getIndustries({bool includeInactive = false}) async {
    throw const ApiException(
      kind: ApiExceptionKind.network,
      message: 'offline',
    );
  }
}
