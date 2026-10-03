import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/marketplace/screens/marketplace_discovery_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_service_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  const Industry industry = Industry(
    id: 'ind-1',
    slug: 'artisans',
    name: 'Artisans',
    isActive: true,
    sortOrder: 10,
  );
  const Profession profession = Profession(
    id: 'prof-9',
    industryId: 'ind-1',
    slug: 'plumber',
    name: 'Plumber',
    isActive: true,
    sortOrder: 10,
  );

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

  MarketplaceSearchProvider searchWith(List<ServiceListing> items) {
    final MarketplaceSearchProvider provider = MarketplaceSearchProvider(
      repository: FakeServiceSearchRepository(items: items),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  TaxonomyProvider taxonomy() {
    final TaxonomyProvider provider = TaxonomyProvider(
      repository: FakeTaxonomyRepository(
        industries: const <Industry>[industry],
        professionsByIndustry: const <String, List<Profession>>{
          'ind-1': <Profession>[profession],
        },
      ),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  group('MarketplaceDiscoveryScreen', () {
    testWidgets('renders ranked rows verbatim (no client re-sort)', (
      WidgetTester tester,
    ) async {
      // Deliberately ordered low-rating-first: any client sort by rating
      // would flip this pair.
      final MarketplaceSearchProvider search = searchWith(<ServiceListing>[
        rankedListing(id: 'low', avgRating: 3.0, score: 0.81),
        rankedListing(id: 'high', avgRating: 5.0, score: 0.80),
      ]);
      await pumpApp(
        tester,
        const MarketplaceDiscoveryScreen(),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      final List<String> order =
          tester
              .widgetList<DiscoveryServiceCard>(
                find.byType(DiscoveryServiceCard),
              )
              .map((DiscoveryServiceCard w) => w.listing.id)
              .toList();
      expect(order, <String>['low', 'high']);
    });

    testWidgets('shows empty state when no services are published', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const MarketplaceDiscoveryScreen(),
        providers: providers(
          search: searchWith(const <ServiceListing>[]),
          taxonomy: taxonomy(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('No services yet'), findsOneWidget);
    });

    testWidgets('profession chip filters the ranked search', (
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
        const MarketplaceDiscoveryScreen(),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      // Browse hierarchy: industry chip, then the profession chip (scoped to
      // chips — result cards also render the profession name).
      await tester.tap(find.widgetWithText(HivorrChip, 'Artisans'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(HivorrChip, 'Plumber'));
      await tester.pumpAndSettle();

      expect(repository.lastProfessionId, 'prof-9');
      expect(search.professionId, 'prof-9');
      expect(
        find.byType(DiscoveryServiceCard, skipOffstage: false),
        findsWidgets,
      );
    });
  });
}
