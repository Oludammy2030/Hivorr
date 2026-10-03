import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/systems/marketplace/screens/marketplace_search_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_service_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  List<SingleChildWidget> providers({
    required MarketplaceSearchProvider search,
    required TaxonomyProvider taxonomy,
  }) => <SingleChildWidget>[
    ChangeNotifierProvider<MarketplaceSearchProvider>.value(value: search),
    ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy),
    Provider<ServiceListingService>.value(
      value: ServiceListingService(
        repository: FakeServiceListingRepository(seed: const []),
      ),
    ),
  ];

  TaxonomyProvider taxonomy() {
    final TaxonomyProvider provider = TaxonomyProvider(
      repository: FakeTaxonomyRepository(),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  group('MarketplaceSearchScreen', () {
    testWidgets('deep-linked query reaches the ranked RPC', (
      WidgetTester tester,
    ) async {
      final FakeServiceSearchRepository repository =
          FakeServiceSearchRepository(
            items: <ServiceListing>[rankedListing(id: 's1')],
          );
      final MarketplaceSearchProvider search = MarketplaceSearchProvider(
        repository: repository,
      );
      addTearDown(search.dispose);

      await pumpApp(
        tester,
        const MarketplaceSearchScreen(initialQuery: 'legal drafting'),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      // Boot waits past the provider query debounce (fake clock needs an
      // explicit advance — settle alone does not fire pending timers).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(repository.lastQuery, 'legal drafting');
      expect(
        find.byType(DiscoveryServiceCard, skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('typing filters through the debounced search', (
      WidgetTester tester,
    ) async {
      final FakeServiceSearchRepository repository =
          FakeServiceSearchRepository(
            items: <ServiceListing>[rankedListing(id: 's1')],
          );
      final MarketplaceSearchProvider search = MarketplaceSearchProvider(
        repository: repository,
      );
      addTearDown(search.dispose);

      await pumpApp(
        tester,
        const MarketplaceSearchScreen(),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();
      final int bootCalls = repository.searchCallCount;

      await tester.enterText(find.byType(TextField).first, 'plumb');
      // Field (250ms) + provider (250ms) + screen trailing (300ms) windows.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(repository.lastQuery, 'plumb');
      expect(repository.searchCallCount, greaterThan(bootCalls));
    });

    testWidgets('PLT004 renders as an empty state, not an error', (
      WidgetTester tester,
    ) async {
      final FakeServiceSearchRepository repository =
          FakeServiceSearchRepository(
            items: const <ServiceListing>[],
          )
            ..searchError = const ApiException(
              kind: ApiExceptionKind.notFound,
              message: 'No matching services.',
              code: 'PLT004',
            );
      final MarketplaceSearchProvider search = MarketplaceSearchProvider(
        repository: repository,
      );
      addTearDown(search.dispose);

      await pumpApp(
        tester,
        const MarketplaceSearchScreen(),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      // No-oracle uniformity: unknown profession reads as empty.
      expect(find.text('No matching services'), findsOneWidget);
      expect(find.text('Could not load services'), findsNothing);
    });
  });
}
