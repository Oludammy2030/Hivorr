import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/models/industry_dto.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

import '../../support/fakes/fake_taxonomy.dart';

void main() {
  group('TaxonomyRepositoryImpl', () {
    test('getIndustries caches remote result locally and maps entities', () async {
      final remote = FakeTaxonomyRemoteDataSource();
      final local = InMemoryTaxonomyLocalDataSource();
      final repo = TaxonomyRepositoryImpl(remote: remote, local: local);

      final List<Industry> industries = await repo.getIndustries();

      expect(industries.length, 3);
      expect(remote.getIndustriesCallCount, 1);
      expect(local, isA<InMemoryTaxonomyLocalDataSource>());
    });

    test('getIndustries uses local cache when present (no remote call)', () async {
      final remote = FakeTaxonomyRemoteDataSource();
      final local = InMemoryTaxonomyLocalDataSource(
        industries: seedIndustryRows.map(IndustryDto.fromJson).toList(),
      );
      final repo = TaxonomyRepositoryImpl(remote: remote, local: local);

      final List<Industry> industries = await repo.getIndustries();

      expect(industries.length, 3);
      expect(remote.getIndustriesCallCount, 0);
    });

    test('getProfessions filters by industryId via remote', () async {
      final remote = FakeTaxonomyRemoteDataSource();
      final local = InMemoryTaxonomyLocalDataSource();
      final repo = TaxonomyRepositoryImpl(remote: remote, local: local);

      final List<Profession> professions = await repo.getProfessions(
        industryId: 'ind-tech',
      );

      expect(professions.length, 3);
      expect(professions.every((Profession p) => p.industryId == 'ind-tech'), isTrue);
    });

    test('getProfessions returns all when industryId is null', () async {
      final remote = FakeTaxonomyRemoteDataSource();
      final local = InMemoryTaxonomyLocalDataSource();
      final repo = TaxonomyRepositoryImpl(remote: remote, local: local);

      final List<Profession> professions = await repo.getProfessions();

      expect(professions.length, 3);
    });

    test('remote error propagates as ApiException', () async {
      final remote = FakeTaxonomyRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
        );
      final local = InMemoryTaxonomyLocalDataSource();
      final repo = TaxonomyRepositoryImpl(remote: remote, local: local);

      expect(
        () => repo.getIndustries(),
        throwsA(isA<ApiException>()),
      );
    });

    test('invalidate clears local cache so the next read refetches', () async {
      final remote = FakeTaxonomyRemoteDataSource();
      final local = InMemoryTaxonomyLocalDataSource(
        industries: seedIndustryRows.map(IndustryDto.fromJson).toList(),
      );
      final repo = TaxonomyRepositoryImpl(remote: remote, local: local);

      await repo.invalidate();

      final List<Industry> industries = await repo.getIndustries();
      expect(remote.getIndustriesCallCount, 1,
          reason: 'empty cache after invalidate -> remote fetch');
      expect(industries, isNotEmpty);
    });
  });
}
