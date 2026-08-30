import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

import '../../support/builders/taxonomy_builders.dart';
import 'taxonomy_fakes.dart';

void main() {
  group('TaxonomyRepositoryImpl (cache-first)', () {
    setUp(() async {
      CacheManager.dispose();
      await CacheManager.initialize(
        CacheConfig(maxEntries: 100, defaultTtl: const Duration(seconds: 300)),
      );
    });

    tearDown(() => CacheManager.dispose());

    test('getIndustries fetches remote on miss, then serves from cache', () async {
      final FakeTaxonomyRemoteDataSource remote =
          FakeTaxonomyRemoteDataSource()
            ..industries = [
              IndustryDtoBuilder()
                  .withId('i1')
                  .withSlug('legal')
                  .withName('Legal')
                  .build(),
            ];
      final TaxonomyRepositoryImpl repo = TaxonomyRepositoryImpl(
        remote: remote,
        local: InMemoryTaxonomyLocalDataSource(),
      );

      final List<Industry> first = await repo.getIndustries();
      expect(first.single.slug, 'legal');
      expect(remote.listIndustriesCallCount, 1);

      final List<Industry> second = await repo.getIndustries();
      expect(second.single.slug, 'legal');
      expect(remote.listIndustriesCallCount, 1, reason: 'cache hit, no refetch');
    });

    test('getProfessions(industryId) is cache-first and scoped', () async {
      final FakeTaxonomyRemoteDataSource remote =
          FakeTaxonomyRemoteDataSource()
            ..professions = [
              ProfessionDtoBuilder()
                  .withIndustryId('i1')
                  .withSlug('notary-public')
                  .withName('Notary Public')
                  .build(),
              ProfessionDtoBuilder()
                  .withIndustryId('i2')
                  .withSlug('electrician')
                  .withName('Electrician')
                  .build(),
            ];
      final TaxonomyRepositoryImpl repo = TaxonomyRepositoryImpl(
        remote: remote,
        local: InMemoryTaxonomyLocalDataSource(),
      );

      final List<Profession> scoped = await repo.getProfessions(
        industryId: 'i1',
      );
      expect(scoped.single.slug, 'notary-public');
      expect(remote.lastListProfessionsIndustryId, 'i1');
      expect(remote.listProfessionsCallCount, 1);

      final List<Profession> scopedAgain = await repo.getProfessions(
        industryId: 'i1',
      );
      expect(scopedAgain.single.slug, 'notary-public');
      expect(remote.listProfessionsCallCount, 1, reason: 'cache hit, no refetch');
    });

    test('getProfessions(null) returns the full corpus (tree path)', () async {
      final FakeTaxonomyRemoteDataSource remote =
          FakeTaxonomyRemoteDataSource()
            ..professions = [
              ProfessionDtoBuilder().withSlug('a').build(),
              ProfessionDtoBuilder().withSlug('b').build(),
            ];
      final TaxonomyRepositoryImpl repo = TaxonomyRepositoryImpl(
        remote: remote,
        local: InMemoryTaxonomyLocalDataSource(),
      );

      final List<Profession> all = await repo.getProfessions();
      expect(all, hasLength(2));
      expect(remote.lastListProfessionsIndustryId, isNull);
    });

    test('propagates ApiException on remote failure', () async {
      final FakeTaxonomyRemoteDataSource remote = FakeTaxonomyRemoteDataSource()
        ..throwError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'A server error occurred.',
          code: 'PLT999',
        );
      final TaxonomyRepositoryImpl repo = TaxonomyRepositoryImpl(
        remote: remote,
        local: InMemoryTaxonomyLocalDataSource(),
      );

      expect(() => repo.getIndustries(), throwsA(isA<ApiException>()));
    });

    test('invalidateTaxonomy clears only taxonomy-prefixed keys', () {
      final CacheManager cache = CacheManager.instance;
      cache.put<String>('taxonomy:industries', 'industries');
      cache.put<String>('taxonomy:professions:i1', 'professions');
      cache.put<String>('entity:1', 'profile');
      final TaxonomyRepositoryImpl repo = TaxonomyRepositoryImpl(
        remote: FakeTaxonomyRemoteDataSource(),
        local: InMemoryTaxonomyLocalDataSource(),
      );

      repo.invalidateTaxonomy();

      expect(cache.get<String>('taxonomy:industries'), isNull);
      expect(cache.get<String>('taxonomy:professions:i1'), isNull);
      expect(cache.get<String>('entity:1'), 'profile',
          reason: 'unrelated prefix intact');
    });
  });
}
