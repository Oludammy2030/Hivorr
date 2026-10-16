import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/systems/marketplace/screens/marketplace_discovery_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  const Industry industry = Industry(
    id: 'ind-1',
    slug: 'technology',
    name: 'Technology',
    isActive: true,
    sortOrder: 10,
  );
  const Profession profession = Profession(
    id: 'prof-9',
    industryId: 'ind-1',
    slug: 'software-engineer',
    name: 'Software Engineer',
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

  group('MarketplaceDiscoveryScreen SEO browse (EP-03-19)', () {
    testWidgets('known industry slug prefilters the ranked search', (
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
        const MarketplaceDiscoveryScreen(initialIndustrySlug: 'technology'),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      expect(repository.lastFilters?.industryId, 'ind-1');
      expect(search.filters.industryId, 'ind-1');
    });

    testWidgets('unknown industry slug renders SEO-404 with browse-all', (
      WidgetTester tester,
    ) async {
      final MarketplaceSearchProvider search = MarketplaceSearchProvider(
        repository: FakeServiceSearchRepository(
          items: <ServiceListing>[rankedListing(id: 's1')],
        ),
      );
      addTearDown(search.dispose);

      await pumpApp(
        tester,
        const MarketplaceDiscoveryScreen(initialIndustrySlug: 'nope'),
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No services found'), findsOneWidget);
      expect(find.text('Browse all services'), findsOneWidget);
    });
  });
}
