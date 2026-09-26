import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';

import '../../support/fakes/fake_service_search.dart';

ServiceListing listing(String id, {double? score}) => ServiceListing(
  id: id,
  entityId: 'entity-$id',
  professionId: 'prof-1',
  industryId: 'ind-1',
  slug: 'slug-$id',
  title: 'Title $id',
  description: 'Description $id xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  pricingType: 'fixed',
  currencyCode: 'NGN',
  avgRating: 4.5,
  reviewCount: 10,
  isTradeVerifiedCache: true,
  score: score,
);

void main() {
  group('MarketplaceSearchProvider', () {
    test('starts idle with no active filters', () {
      final repo = FakeServiceSearchRepository();
      final provider = MarketplaceSearchProvider(repository: repo);

      expect(provider.state, MarketplaceSearchState.idle);
      expect(provider.items, isEmpty);
      expect(provider.hasActiveFilters, isFalse);
      expect(provider.isEmpty, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('search assigns RPC items verbatim (no resort, AGENT.md:7)', () async {
      final repo = FakeServiceSearchRepository(
        items: <ServiceListing>[
          listing('c', score: 0.75),
          listing('a', score: 0.95),
          listing('b', score: 0.85),
        ],
      );
      final provider = MarketplaceSearchProvider(repository: repo);

      await provider.search();

      expect(provider.state, MarketplaceSearchState.loaded);
      // Verbatim RPC order — not score-sorted.
      expect(
        provider.items.map((ServiceListing e) => e.id),
        <String>['c', 'a', 'b'],
      );
      expect(repo.searchCallCount, 1);
    });

    test('hasActiveFilters reflects profession, filters, and query', () {
      final repo = FakeServiceSearchRepository();
      final provider = MarketplaceSearchProvider(repository: repo);

      provider.setProfessionId('prof-1');
      expect(provider.hasActiveFilters, isTrue);

      provider.setProfessionId(null);
      expect(provider.hasActiveFilters, isFalse);

      provider.setFilters(const ServiceSearchFilters(ratingMin: 4.5));
      expect(provider.hasActiveFilters, isTrue);

      provider.setFilters(const ServiceSearchFilters());
      expect(provider.hasActiveFilters, isFalse);
    });

    test('setQuery debounces 250ms before notifying', () {
      final repo = FakeServiceSearchRepository();
      final provider = MarketplaceSearchProvider(repository: repo);

      FakeAsync().run((FakeAsync async) {
        provider.setQuery('legal');
        expect(provider.query, isEmpty);
        expect(provider.hasActiveFilters, isFalse);

        async.elapse(const Duration(milliseconds: 250));

        expect(provider.query, 'legal');
        expect(provider.hasActiveFilters, isTrue);
      });
    });

    test('clearQuery clears immediately without debounce', () {
      final repo = FakeServiceSearchRepository();
      final provider = MarketplaceSearchProvider(repository: repo);

      FakeAsync().run((FakeAsync async) {
        provider.setQuery('legal');
        async.elapse(const Duration(milliseconds: 250));
        expect(provider.query, 'legal');

        provider.clearQuery();
        expect(provider.query, isEmpty);
        expect(provider.hasActiveFilters, isFalse);
      });
    });

    test('refresh is a no-op until loaded', () async {
      final repo = FakeServiceSearchRepository(
        items: <ServiceListing>[listing('a', score: 0.9)],
      );
      final provider = MarketplaceSearchProvider(repository: repo);

      await provider.refresh();
      expect(repo.searchCallCount, 0);

      await provider.search();
      expect(provider.state, MarketplaceSearchState.loaded);
      expect(repo.searchCallCount, 1);

      await provider.refresh();
      expect(repo.searchCallCount, 2);
      expect(provider.state, MarketplaceSearchState.loaded);
    });

    test('invalidate resets to idle and clears items', () async {
      final repo = FakeServiceSearchRepository(
        items: <ServiceListing>[listing('a', score: 0.9)],
      );
      final provider = MarketplaceSearchProvider(repository: repo);

      await provider.search();
      expect(provider.items, isNotEmpty);

      await provider.invalidate();

      expect(provider.state, MarketplaceSearchState.idle);
      expect(provider.items, isEmpty);
      expect(provider.hasMore, isFalse);
      expect(provider.nextCursor, isNull);
      expect(repo.invalidateCallCount, 1);
    });
  });
}
