// Run: flutter test test/integration/marketplace/ranking_determinism_integration_test.dart
//
// EP-03-20 VP3 — Ranked search determinism (server order preserved verbatim).
// Verifies the client never re-sorts RPC results; the `rank_weights_version`
// is surfaced read-only. Server-side determinism (pgTAP 034 + staging
// double-call) is an operator gate — recorded in the verification report.
// The ranking-override scan provides the static "no client re-sort" backing.

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';

import '../../support/fakes/fake_service_search.dart';

/// Builds a minimal ranked listing fixture (score is the ranking key).
ServiceListing _ranked(String id, double score, double price) => ServiceListing(
  id: id,
  entityId: 'e1',
  professionId: 'p1',
  industryId: 'i1',
  slug: id,
  title: 'Listing $id',
  description: 'A marketplace listing body exceeding fifty characters.',
  pricingType: 'fixed',
  priceMin: price,
  currencyCode: 'NGN',
  avgRating: 4.0,
  reviewCount: 10,
  isTradeVerifiedCache: true,
  score: score,
);

void main() {
  group('EP-03-20 VP3 — search ranked determinism', () {
    late FakeServiceSearchRepository repo;
    late MarketplaceSearchProvider provider;

    setUp(() {
      repo = FakeServiceSearchRepository();
      provider = MarketplaceSearchProvider(repository: repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test(
      'DoD-VP3a: provider assigns items verbatim (never re-sorts)',
      () async {
        // Arrange: deliberately NOT sorted by price or rating — the server
        // order is (a) highest score first.
        final List<ServiceListing> items = <ServiceListing>[
          _ranked('a', 0.91, 5000),
          _ranked('b', 0.87, 1000),
          _ranked('c', 0.72, 9000),
        ];
        repo.items = items;

        // Act: execute the search.
        await provider.search();

        // Assert: identical list instance/order — no client-side re-sort.
        expect(provider.items, same(items));
        expect(
          provider.items.map((ServiceListing e) => e.id).toList(),
          <String>['a', 'b', 'c'],
        );
        // Scores are monotonically non-increasing (server rank order intact).
        final List<double?> scores = provider.items
            .map((ServiceListing e) => e.score)
            .toList();
        for (var i = 1; i < scores.length; i++) {
          expect(scores[i]!, lessThanOrEqualTo(scores[i - 1]!));
        }
      },
    );

    test('DoD-VP3b: repeated search returns identical order', () async {
      final List<ServiceListing> items = <ServiceListing>[
        _ranked('x', 0.66, 1000),
        _ranked('y', 0.95, 5000),
      ];
      repo.items = items;

      await provider.search();
      final List<String> first = provider.items
          .map((ServiceListing e) => e.id)
          .toList();

      await provider.invalidate();
      repo.items = items;
      await provider.search();
      final List<String> second = provider.items
          .map((ServiceListing e) => e.id)
          .toList();

      // Verbatim payload order both times — even though `y` scores higher,
      // the client never re-sorts by score (server owns ordering).
      expect(first, <String>['x', 'y']);
      expect(second, <String>['x', 'y']);
    });

    test('DoD-VP3c: rank_weights_version surfaced read-only', () async {
      // Arrange: the fake reports a server weights_version stamp.
      final DateTime weightsVersion = DateTime.utc(2026, 10, 1);
      repo = FakeServiceSearchRepository(
        items: <ServiceListing>[_ranked('a', 0.9, 1000)],
        weightsVersion: weightsVersion,
      );
      provider = MarketplaceSearchProvider(repository: repo);

      // Act: search surfaces the version.
      await provider.search();

      // Assert: read-only surfacing — the provider never mutates it.
      expect(provider.weightsVersion, weightsVersion);
    });
  });
}
