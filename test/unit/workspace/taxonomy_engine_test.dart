import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/workspace/profession_registry/profession_registry_service.dart';

import '../../support/builders/taxonomy_builders.dart';
import '../data/taxonomy_fakes.dart';

void main() {
  group('ProfessionRegistryService', () {
    test('search is case-insensitive substring on slug and name', () {
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: FakeTaxonomyRepository(),
      );

      final List<Profession> hits = service.searchProfessions(
        'ENGINEER',
        <Profession>[
          ProfessionBuilder()
              .withId('p1')
              .withSlug('software-engineer')
              .withName('Software Engineer')
              .build(),
          ProfessionBuilder()
              .withId('p2')
              .withSlug('civil-engineer')
              .withName('Civil Engineer')
              .build(),
          ProfessionBuilder()
              .withId('p3')
              .withSlug('plumber')
              .withName('Plumber')
              .build(),
        ],
      );

      expect(hits.map((Profession p) => p.id), <String>['p1', 'p2']);
    });

    test('search matches name even when slug does not', () {
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: FakeTaxonomyRepository(),
      );

      final List<Profession> hits = service.searchProfessions(
        'plumb',
        <Profession>[
          ProfessionBuilder()
              .withId('p1')
              .withSlug('plumber')
              .withName('Plumber')
              .build(),
        ],
      );

      expect(hits.single.id, 'p1');
    });

    test('empty query returns full corpus in given order', () {
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: FakeTaxonomyRepository(),
      );

      final List<Profession> hits = service.searchProfessions(
        '',
        <Profession>[
          ProfessionBuilder().withId('b').build(),
          ProfessionBuilder().withId('a').build(),
        ],
      );

      expect(hits.map((Profession p) => p.id), <String>['b', 'a']);
    });

    test('tree groups professions under their owning industry, preserving '
        'source sort order', () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        industries: <Industry>[
          // Supplied in `sortOrder ASC` (as the RPC returns them).
          IndustryBuilder()
              .withId('i1')
              .withSlug('technology')
              .withName('Technology')
              .withSortOrder(10)
              .build(),
          IndustryBuilder()
              .withId('i2')
              .withSlug('legal')
              .withName('Legal')
              .withSortOrder(20)
              .build(),
        ],
        professions: <Profession>[
          ProfessionBuilder()
              .withId('p1')
              .withIndustryId('i1')
              .withSlug('dev')
              .withName('Developer')
              .build(),
          ProfessionBuilder()
              .withId('p2')
              .withIndustryId('i2')
              .withSlug('lawyer')
              .withName('Lawyer')
              .build(),
        ],
      );
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: repository,
      );

      final TaxonomyTree tree = await service.getTree();

      expect(tree.keys.map((Industry i) => i.slug), <String>[
        'technology',
        'legal',
      ]);
      expect(tree[repository.industries[0]]!.single.name, 'Developer');
      expect(tree[repository.industries[1]]!.single.name, 'Lawyer');
    });

    test('browseIndustries delegates to repository', () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        industries: <Industry>[
          IndustryBuilder().withSlug('legal').build(),
        ],
      );
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: repository,
      );

      final List<Industry> industries = await service.browseIndustries();
      expect(industries.single.slug, 'legal');
      expect(repository.getIndustriesCallCount, 1);
    });

    test('professionsByIndustry delegates and returns only that industry',
        () async {
      final FakeTaxonomyRepository repository = FakeTaxonomyRepository(
        professions: <Profession>[
          ProfessionBuilder().withIndustryId('i1').withSlug('a').build(),
          ProfessionBuilder().withIndustryId('i2').withSlug('b').build(),
        ],
      );
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: repository,
      );

      final List<Profession> scoped = await service.professionsByIndustry('i1');
      expect(scoped.single.slug, 'a');
      expect(repository.getProfessionsCallCount, 1);
    });

    test('getIndustryBySlug and getProfessionBySlug resolve entities', () {
      final ProfessionRegistryService service = ProfessionRegistryService(
        repository: FakeTaxonomyRepository(
          industries: <Industry>[
            IndustryBuilder().withId('i1').withSlug('legal').build(),
          ],
          professions: <Profession>[
            ProfessionBuilder()
                .withId('p1')
                .withIndustryId('i1')
                .withSlug('lawyer')
                .build(),
          ],
        ),
      );

      final List<Industry> industries = <Industry>[
        IndustryBuilder().withId('i1').withSlug('legal').build(),
      ];
      final List<Profession> professions = <Profession>[
        ProfessionBuilder()
            .withId('p1')
            .withIndustryId('i1')
            .withSlug('lawyer')
            .build(),
      ];

      expect(service.getIndustryBySlug(industries, 'legal')?.id, 'i1');
      expect(service.getIndustryBySlug(industries, 'nope'), isNull);
      expect(service.getProfessionBySlug(professions, 'lawyer')?.id, 'p1');
      expect(service.getProfessionBySlug(professions, 'nope'), isNull);
    });
  });
}