import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/engine/search_engine/service_search_index.dart';
import 'package:hivorr/workspace/profession_registry/taxonomy_engine.dart';

import '../../../support/fakes/fake_service_search.dart';
import '../../../support/fakes/fake_taxonomy.dart';

void main() {
  ServiceListing listing(String id, {double? score}) => ServiceListing(
    id: id,
    entityId: 'entity-$id',
    professionId: 'prof-1',
    industryId: 'ind-1',
    slug: 'slug-$id',
    title: 'Title $id',
    description: 'Description $id' * 10,
    pricingType: 'fixed',
    currencyCode: 'NGN',
    avgRating: 4.5,
    reviewCount: 10,
    isTradeVerifiedCache: true,
    score: score,
  );

  group('ServiceSearchIndex', () {
    late FakeServiceSearchRepository repository;
    late FakeTaxonomyRepository taxonomyRepo;
    late TaxonomyEngine taxonomy;
    late ServiceSearchIndex index;

    setUp(() {
      repository = FakeServiceSearchRepository(
        items: <ServiceListing>[
          listing('a', score: 0.95),
          listing('b', score: 0.85),
          listing('c', score: 0.75),
        ],
        hasMore: false,
      );
      taxonomyRepo = FakeTaxonomyRepository(
        industries: <Industry>[
          const Industry(
            id: 'ind-tech',
            slug: 'technology',
            name: 'Technology',
            isActive: true,
            sortOrder: 10,
          ),
        ],
        professionsByIndustry: <String, List<Profession>>{
          'ind-tech': <Profession>[
            const Profession(
              id: 'prof-sw',
              industryId: 'ind-tech',
              slug: 'software-engineer',
              name: 'Software Engineer',
              isActive: true,
              sortOrder: 10,
            ),
            const Profession(
              id: 'prof-web',
              industryId: 'ind-tech',
              slug: 'web-developer',
              name: 'Web Developer',
              isActive: true,
              sortOrder: 20,
            ),
          ],
        },
      );
      taxonomy = TaxonomyEngine(repository: taxonomyRepo);
      index = ServiceSearchIndex(repository: repository, taxonomy: taxonomy);
    });

    test('warmBrowse returns ranked page verbatim (no resort)', () async {
      final ServiceSearchPage page = await index.warmBrowse(
        professionId: 'prof-sw',
        limit: 20,
      );

      expect(page.items, hasLength(3));
      expect(page.items[0].id, 'a');
      expect(page.items[1].id, 'b');
      expect(page.items[2].id, 'c');
      expect(repository.searchCallCount, 1);
      expect(repository.lastProfessionId, 'prof-sw');
      expect(repository.lastQuery, isNull);
    });

    test('warmBrowse with null professionId pre-warms unscoped browse', () async {
      await index.warmBrowse(professionId: null);

      expect(repository.searchCallCount, 1);
      expect(repository.lastProfessionId, isNull);
    });

    test('hydrateOffline pre-warms unscoped + per-profession pages', () async {
      final int count = await index.hydrateOffline(limit: 20);

      // 1 unscoped + 2 professions from 1 industry = 3 total.
      expect(count, 3);
      expect(repository.searchCallCount, 3);
    });

    test('hydrateOffline respects warmProfessionCount cap', () async {
      // Add more professions to exceed cap.
      final List<Profession> manyProfessions = List<Profession>.generate(
        25,
        (int i) => Profession(
          id: 'prof-$i',
          industryId: 'ind-tech',
          slug: 'prof-$i',
          name: 'Profession $i',
          isActive: true,
          sortOrder: i * 10,
        ),
      );
      taxonomyRepo = FakeTaxonomyRepository(
        industries: <Industry>[
          const Industry(
            id: 'ind-tech',
            slug: 'technology',
            name: 'Technology',
            isActive: true,
            sortOrder: 10,
          ),
        ],
        professionsByIndustry: <String, List<Profession>>{
          'ind-tech': manyProfessions,
        },
      );
      taxonomy = TaxonomyEngine(repository: taxonomyRepo);
      index = ServiceSearchIndex(repository: repository, taxonomy: taxonomy);

      final int count = await index.hydrateOffline();

      // 1 unscoped + warmProfessionCount (20) = 21.
      expect(count, 21);
      expect(repository.searchCallCount, 21);
    });

    test('warmBrowse preserves RPC order (AGENT.md:7)', () async {
      // Server returns items in deterministic rank order; index must not resort.
      final ServiceSearchPage page = await index.warmBrowse();

      // Items are in repository-returned order (a, b, c by score DESC).
      expect(page.items.map((ServiceListing e) => e.id), <String>['a', 'b', 'c']);
    });
  });
}
