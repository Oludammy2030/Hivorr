// Run: flutter test test/integration/marketplace/search_pagination_integration_test.dart
//
// EP-03-20 VP4 — Ranked, keyset-paginated search with filter round-trip.
// Uses the extended FakeServiceSearchRepository scripted `pages` seam so
// page 2 is served only when the provider round-trips the exact
// `(score,id)` cursor. Asserts page-2 excludes page-1, `hasMore` exhaustion,
// filter round-trip, and no unbounded fetch (call-count + explicit limit).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/systems/marketplace/screens/marketplace_search_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

/// Builds a minimal ranked listing fixture for pagination.
ServiceListing _ranked(String id, double score) => ServiceListing(
  id: id,
  entityId: 'e1',
  professionId: 'p1',
  industryId: 'i1',
  slug: id,
  title: 'Listing $id',
  description: 'A marketplace listing body exceeding fifty characters.',
  pricingType: 'fixed',
  priceMin: 1000,
  currencyCode: 'NGN',
  avgRating: 4.0,
  reviewCount: 10,
  isTradeVerifiedCache: true,
  score: score,
);

/// Builds the scripted two-page keyset fixture: page 2 is disjoint from
/// page 1 and is only served on an exact cursor round-trip.
FakeServiceSearchRepository _pagedRepo() {
  final ServiceSearchPage page1 = ServiceSearchPage(
    items: <ServiceListing>[_ranked('p1', 0.9), _ranked('p2', 0.8)],
    hasMore: true,
    nextCursor: const ServiceListingCursor(score: 0.8, id: 'p2'),
  );
  final ServiceSearchPage page2 = ServiceSearchPage(
    items: <ServiceListing>[_ranked('p3', 0.7), _ranked('p4', 0.6)],
    hasMore: false,
    nextCursor: null,
  );
  return FakeServiceSearchRepository()
    ..pages = <ServiceSearchPage>[page1, page2];
}

void main() {
  group('EP-03-20 VP4 — ranked keyset pagination', () {
    late FakeServiceSearchRepository repo;
    late MarketplaceSearchProvider provider;

    setUp(() {
      repo = _pagedRepo();
      provider = MarketplaceSearchProvider(repository: repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test('DoD-VP4a: page 2 excludes page 1 (keyset round-trip)', () async {
      // Act: load page 1 then page 2 via the provider cursor.
      await provider.search();
      final List<String> page1Ids = provider.items
          .map((ServiceListing e) => e.id)
          .toList();
      expect(page1Ids, <String>['p1', 'p2']);
      expect(provider.hasMore, isTrue);
      expect(provider.nextCursor, isNotNull);

      await provider.loadMore();
      final List<String> allIds = provider.items
          .map((ServiceListing e) => e.id)
          .toList();

      // Assert: page 2 appended and is disjoint from page 1 (no dupes).
      expect(allIds, <String>['p1', 'p2', 'p3', 'p4']);
      final Set<String> page2Ids = allIds.toSet().difference(page1Ids.toSet());
      expect(page2Ids, <String>{'p3', 'p4'});
      expect(allIds.toSet().length, allIds.length, reason: 'no duplicate ids');

      // The provider round-tripped the exact page-1 cursor.
      expect(repo.lastCursor, isNotNull);
      expect(repo.lastCursor!.id, 'p2');
      expect(repo.lastCursor!.score, 0.8);
    });

    test('DoD-VP4b: hasMore exhaustion stops the cursor chain', () async {
      // Act: search + loadMore until the terminal page.
      await provider.search();
      await provider.loadMore();

      // Assert: terminal page clears hasMore/nextCursor.
      expect(provider.hasMore, isFalse);
      expect(provider.nextCursor, isNull);

      // A further loadMore is a no-op (no extra repository call).
      final int callsBefore = repo.searchCallCount;
      await provider.loadMore();
      expect(repo.searchCallCount, callsBefore);
    });

    test('DoD-VP4c: filters round-trip to the repository', () async {
      // Arrange: an active filter set.
      const ServiceSearchFilters filters = ServiceSearchFilters(
        professionId: 'prof-1',
        industryId: 'ind-1',
        ratingMin: 4.0,
        isTradeVerifiedOnly: true,
      );
      provider.setFilters(filters);

      // Act: execute the search.
      await provider.search();

      // Assert: the filters object reached the repository verbatim.
      expect(repo.lastFilters, isNotNull);
      expect(repo.lastFilters!.professionId, 'prof-1');
      expect(repo.lastFilters!.industryId, 'ind-1');
      expect(repo.lastFilters!.ratingMin, 4.0);
      expect(repo.lastFilters!.isTradeVerifiedOnly, isTrue);
      expect(provider.hasActiveFilters, isTrue);
    });

    test(
      'DoD-VP4d: no unbounded fetch (bounded limit + one call per page)',
      () async {
        // Act: an explicit limit is forwarded; each page is exactly one call.
        await provider.search(limit: 10);
        expect(repo.lastLimit, 10);
        expect(repo.searchCallCount, 1);

        await provider.loadMore(limit: 10);
        expect(repo.lastLimit, 10);
        expect(repo.searchCallCount, 2);
        // Two pages, four items — nothing was fetched unbounded.
        expect(provider.items.length, 4);
      },
    );

    testWidgets('DoD-VP4e: ranked results render without overflow across the '
        'responsive matrix (390/600/1024/1280)', (WidgetTester tester) async {
      // UI-02 / decision D2: no golden infrastructure exists, so the
      // responsive no-overflow matrix substitutes for goldens. The 390 px band
      // is asserted at dpr 3 (physical 1170) exactly as the DoD requires; the
      // wider bands run at dpr 1.
      const List<List<num>> matrix = <List<num>>[
        <num>[390, 3],
        <num>[600, 1],
        <num>[1024, 1],
        <num>[1280, 1],
      ];

      final MarketplaceSearchProvider search = MarketplaceSearchProvider(
        repository: _pagedRepo(),
      );
      addTearDown(search.dispose);
      final TaxonomyProvider taxonomy = TaxonomyProvider(
        repository: FakeTaxonomyRepository(),
      );
      addTearDown(taxonomy.dispose);
      final ServiceListingService service = ServiceListingService(
        repository: FakeServiceListingRepository(seed: const []),
      );
      final List<SingleChildWidget> providers = <SingleChildWidget>[
        ChangeNotifierProvider<MarketplaceSearchProvider>.value(value: search),
        ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy),
        Provider<ServiceListingService>.value(value: service),
      ];

      for (final List<num> band in matrix) {
        final double width = band[0].toDouble();
        final double dpr = band[1].toDouble();
        tester.view.physicalSize = Size(width * dpr, 844 * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);

        await pumpApp(
          tester,
          const MarketplaceSearchScreen(initialQuery: 'legal'),
          providers: providers,
        );
        // The screen's search is debounced; advance the fake clock explicitly.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Assert: the ranked list rendered and no layout/overflow exception
        // was thrown at this viewport.
        expect(
          find.byType(MarketplaceSearchScreen),
          findsOneWidget,
          reason: 'screen must render at ${width.toInt()}px',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow/exception at ${width.toInt()}px (dpr $dpr)',
        );
      }
    });
  });
}
