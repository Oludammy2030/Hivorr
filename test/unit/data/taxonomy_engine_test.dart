import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/workspace/profession_registry/taxonomy_engine.dart';

import '../../support/fakes/fake_taxonomy.dart';

void main() {
  Industry industry({
    required String id,
    required String slug,
    required String name,
    required int sortOrder,
  }) => Industry(
    id: id,
    slug: slug,
    name: name,
    isActive: true,
    sortOrder: sortOrder,
  );

  Profession profession({
    required String id,
    required String industryId,
    required String name,
    required String slug,
    required int sortOrder,
  }) => Profession(
    id: id,
    industryId: industryId,
    slug: slug,
    name: name,
    isActive: true,
    sortOrder: sortOrder,
  );

  final List<Industry> industries = <Industry>[
    industry(id: 'ind-tech', slug: 'technology', name: 'Technology', sortOrder: 20),
    industry(id: 'ind-legal', slug: 'legal', name: 'Legal', sortOrder: 10),
    industry(id: 'ind-health', slug: 'healthcare', name: 'Healthcare', sortOrder: 30),
  ];

  final Map<String, List<Profession>> professionsByIndustry =
      <String, List<Profession>>{
    'ind-tech': <Profession>[
      profession(id: 'prof-sw', industryId: 'ind-tech', name: 'Software Engineer', slug: 'software-engineer', sortOrder: 10),
      profession(id: 'prof-mobile', industryId: 'ind-tech', name: 'Mobile Developer', slug: 'mobile-developer', sortOrder: 30),
      profession(id: 'prof-web', industryId: 'ind-tech', name: 'Web Developer', slug: 'web-developer', sortOrder: 20),
    ],
  };

  group('TaxonomyEngine', () {
    test('browseIndustries sorts by sortOrder', () async {
      final engine = TaxonomyEngine(
        repository: FakeTaxonomyRepository(industries: industries),
      );

      final List<Industry> result = await engine.browseIndustries();

      expect(result.map((Industry i) => i.slug),
          <String>['legal', 'technology', 'healthcare']);
    });

    test('browseProfessions enforces hierarchical scope and order', () async {
      final engine = TaxonomyEngine(
        repository: FakeTaxonomyRepository(
          industries: industries,
          professionsByIndustry: professionsByIndustry,
        ),
      );

      final List<Profession> result = await engine.browseProfessions('ind-tech');

      expect(result.map((Profession p) => p.slug), <String>[
        'software-engineer',
        'web-developer',
        'mobile-developer',
      ]);
      expect(result.every((Profession p) => p.industryId == 'ind-tech'), isTrue);
    });

    test('search matches substring across name/slug case-insensitively', () {
      final engine = TaxonomyEngine(
        repository: FakeTaxonomyRepository(),
      );
      final List<Profession> scope = professionsByIndustry['ind-tech']!;

      final List<Profession> result = engine.search('soft', scope);
      expect(result.length, 1);
      expect(result.single.name, 'Software Engineer');
    });

    test('search returns scope unfiltered for empty query', () {
      final engine = TaxonomyEngine(repository: FakeTaxonomyRepository());
      final List<Profession> scope = professionsByIndustry['ind-tech']!;

      expect(engine.search('   ', scope).length, scope.length);
      expect(engine.search('', scope).length, scope.length);
    });

    test('search truncates queries longer than 100 chars without throwing', () {
      final engine = TaxonomyEngine(repository: FakeTaxonomyRepository());
      final List<Profession> scope = professionsByIndustry['ind-tech']!;
      final String longQuery = 'a' * 200;

      expect(engine.search(longQuery, scope), isEmpty);
    });

    test('industryForProfession reverse-lookup returns owning industry', () async {
      final engine = TaxonomyEngine(
        repository: FakeTaxonomyRepository(
          industries: industries,
          professionsByIndustry: professionsByIndustry,
        ),
      );

      final Industry? owner = await engine.industryForProfession('prof-web');
      expect(owner?.slug, 'technology');
    });

    test('industryForProfession returns null for unknown profession', () async {
      final engine = TaxonomyEngine(
        repository: FakeTaxonomyRepository(
          industries: industries,
          professionsByIndustry: professionsByIndustry,
        ),
      );

      final Industry? owner = await engine.industryForProfession('does-not-exist');
      expect(owner, isNull);
    });
  });
}
