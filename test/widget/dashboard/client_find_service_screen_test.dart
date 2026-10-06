import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/dashboard/screens/client_find_service_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_service_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_service_search.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

/// Option rows in the select surfaces carry stable keys so same-label rows
/// behind the overlay can never match.
Finder selectOption(String label) =>
    find.byKey(ValueKey<String>('hivorr-select-option-$label'));

Future<void> pickFilterOption(
  WidgetTester tester, {
  required String trigger,
  required String optionLabel,
}) async {
  await tester.tap(find.text(trigger));
  await tester.pumpAndSettle();
  await tester.tap(selectOption(optionLabel));
  await tester.pumpAndSettle();
}

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

  group('ClientFindServiceScreen', () {
    testWidgets(
      'desktop renders one workspace and filters apply in place',
      (WidgetTester tester) async {
        final MarketplaceSearchProvider search = searchWith(
          <ServiceListing>[rankedListing(id: 's1')],
        );
        await pumpScreen(
          tester,
          const ClientFindServiceScreen(),
          width: 1280,
          height: 900,
          providers: providers(search: search, taxonomy: taxonomy()),
        );
        await tester.pumpAndSettle();

        // Single cohesive workspace: inline search, filter entry, browse,
        // ranked results — no second page.
        expect(find.byType(TextField), findsWidgets);
        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('Browse by profession'), findsOneWidget);
        expect(
          find.byType(DiscoveryServiceCard, skipOffstage: false),
          findsWidgets,
        );
        final int bootCalls =
            (search.repository as FakeServiceSearchRepository).searchCallCount;

        // Filter opens as a contextual overlay above the same workspace.
        await tester.tap(find.text('Filters'));
        await tester.pumpAndSettle();
        expect(find.text('Filter services'), findsOneWidget);
        expect(find.text('Browse by profession'), findsOneWidget);

        // Compact selects: industry scopes the dependent profession list.
        await pickFilterOption(
          tester,
          trigger: 'Select industry',
          optionLabel: 'Artisans',
        );
        await pickFilterOption(
          tester,
          trigger: 'Select profession',
          optionLabel: 'Plumber',
        );

        await tester.ensureVisible(find.text('Apply filters'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply filters'));
        await tester.pumpAndSettle();

        // Overlay closed, same workspace, filters applied, query preserved.
        expect(find.text('Filter services'), findsNothing);
        expect(find.text('Browse by profession'), findsOneWidget);
        expect(search.filters.industryId, 'ind-1');
        expect(search.filters.professionId, 'prof-9');
        expect(
          (search.repository as FakeServiceSearchRepository).searchCallCount,
          greaterThan(bootCalls),
        );
        // Active filters communicated as dismissible chips.
        expect(find.widgetWithText(HivorrChip, 'Artisans'), findsWidgets);
        expect(find.widgetWithText(HivorrChip, 'Plumber'), findsWidgets);
      },
    );

    testWidgets('mobile Cancel dismisses the sheet without applying', (
      WidgetTester tester,
    ) async {
      final MarketplaceSearchProvider search = searchWith(
        <ServiceListing>[rankedListing(id: 's1')],
      );
      await pumpScreen(
        tester,
        const ClientFindServiceScreen(),
        width: 390,
        height: 844,
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Filter services'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Filter services'), findsNothing);
      expect(search.filters.isEmpty, isTrue);
      expect(find.text('Browse by profession'), findsOneWidget);
    });

    testWidgets('Clear filters restores unfiltered results in place', (
      WidgetTester tester,
    ) async {
      final MarketplaceSearchProvider search = searchWith(
        <ServiceListing>[rankedListing(id: 's1')],
      );
      search.setFilters(
        const ServiceSearchFilters(industryId: 'ind-1', priceMin: 1000),
      );
      await pumpScreen(
        tester,
        const ClientFindServiceScreen(),
        width: 1280,
        height: 900,
        providers: providers(search: search, taxonomy: taxonomy()),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(HivorrChip, 'Artisans'), findsWidgets);
      await tester.tap(find.widgetWithText(HivorrChip, 'Clear filters'));
      await tester.pumpAndSettle();

      expect(search.filters.isEmpty, isTrue);
      expect(find.text('Browse by profession'), findsOneWidget);
      expect(
        find.byType(DiscoveryServiceCard, skipOffstage: false),
        findsWidgets,
      );
    });
  });
}
