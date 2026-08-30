import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';

import '../../support/builders/taxonomy_builders.dart';
import 'taxonomy_fakes.dart';

void main() {
  group('TaxonomyProvider', () {
    test('starts idle with empty data', () {
      final TaxonomyProvider provider = TaxonomyProvider(
        repository: FakeTaxonomyRepository(),
      );

      expect(provider.state, TaxonomyProviderState.idle);
      expect(provider.industries, isEmpty);
      expect(provider.professions, isEmpty);
      expect(provider.searchResults, isEmpty);
      expect(provider.selectedIndustryId, isNull);
      expect(provider.error, isNull);
    });

    test('loadIndustries resolves to loaded and selects the first industry',
        () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        industries: <Industry>[
          IndustryBuilder().withId('i1').build(),
          IndustryBuilder().withId('i2').build(),
        ],
      );
      final TaxonomyProvider provider = TaxonomyProvider(repository: repository);

      await provider.loadIndustries();

      expect(provider.state, TaxonomyProviderState.loaded);
      expect(provider.industries, hasLength(2));
      expect(provider.selectedIndustryId, 'i1');
      expect(provider.error, isNull);
    });

    test('loadProfessions fills professions and search results', () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        professions: <Profession>[
          ProfessionBuilder().withIndustryId('i1').withSlug('a').build(),
          ProfessionBuilder().withIndustryId('i2').withSlug('b').build(),
        ],
      );
      final TaxonomyProvider provider = TaxonomyProvider(repository: repository);

      await provider.loadProfessions('i1');

      expect(provider.state, TaxonomyProviderState.loaded);
      expect(provider.selectedIndustryId, 'i1');
      expect(provider.professions.map((Profession p) => p.slug), <String>['a']);
      expect(provider.searchResults, provider.professions);
    });

    test('selectIndustry changes the selection without reloading', () {
      final TaxonomyProvider provider = TaxonomyProvider(
        repository: FakeTaxonomyRepository(),
      );

      provider.selectIndustry('i2');

      expect(provider.selectedIndustryId, 'i2');
      expect(provider.state, TaxonomyProviderState.idle,
          reason: 'selection is not an async load');
    });

    test('search filters in-memory and empty query restores the full list',
        () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        professions: <Profession>[
          ProfessionBuilder()
              .withSlug('software-engineer')
              .withName('Software Engineer')
              .build(),
          ProfessionBuilder()
              .withSlug('civil-engineer')
              .withName('Civil Engineer')
              .build(),
          ProfessionBuilder().withSlug('plumber').withName('Plumber').build(),
        ],
      );
      final TaxonomyProvider provider = TaxonomyProvider(repository: repository);
      await provider.loadProfessions('industry-001');

      provider.search('ENGINEER');
      expect(
        provider.searchResults.map((Profession p) => p.slug),
        <String>['software-engineer', 'civil-engineer'],
      );
      expect(provider.state, TaxonomyProviderState.loaded,
          reason: 'search never changes state');

      provider.search('');
      expect(provider.searchResults, provider.professions);

      provider.search('plumb');
      expect(provider.searchResults.single.slug, 'plumber');
    });

    test('clearSearch restores the full list', () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        professions: <Profession>[
          ProfessionBuilder().withSlug('alpha').build(),
          ProfessionBuilder().withSlug('bravo').build(),
        ],
      );
      final TaxonomyProvider provider = TaxonomyProvider(repository: repository);
      await provider.loadProfessions('industry-001');
      provider.search('alpha');
      expect(provider.searchResults, hasLength(1));

      provider.clearSearch();
      expect(provider.searchResults, provider.professions);
    });

    test('retryLoad without selection reloads industries, else professions',
        () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        industries: <Industry>[
          IndustryBuilder().withId('i1').build(),
        ],
        professions: <Profession>[
          ProfessionBuilder().withIndustryId('i1').withSlug('a').build(),
        ],
      );
      final TaxonomyProvider provider = TaxonomyProvider(repository: repository);

      await provider.retryLoad();
      expect(repository.getIndustriesCallCount, 1);
      expect(provider.selectedIndustryId, 'i1');

      await provider.retryLoad();
      expect(repository.getProfessionsCallCount, 1);
      expect(provider.professions, hasLength(1));
    });

    test('surfaces ApiException and parks the provider in error', () async {
      final ApiException expected = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Network unreachable',
        code: 'NW001',
      );
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository()
        ..throwError = expected;
      final TaxonomyProvider provider = TaxonomyProvider(repository: repository);

      await provider.loadIndustries();

      expect(provider.state, TaxonomyProviderState.error);
      expect(provider.error, expected);
    });
  });
}