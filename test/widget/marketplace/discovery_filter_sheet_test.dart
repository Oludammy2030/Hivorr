import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_filter_sheet.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  TaxonomyProvider taxonomy() {
    final TaxonomyProvider provider = TaxonomyProvider(
      repository: FakeTaxonomyRepository(
        industries: const <Industry>[
          Industry(
            id: 'ind-1',
            slug: 'artisans',
            name: 'Artisans',
            isActive: true,
            sortOrder: 10,
          ),
        ],
        professionsByIndustry: const <String, List<Profession>>{
          'ind-1': <Profession>[
            Profession(
              id: 'prof-9',
              industryId: 'ind-1',
              slug: 'plumber',
              name: 'Plumber',
              isActive: true,
              sortOrder: 10,
            ),
          ],
        },
      ),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  group('DiscoveryFilterSheet', () {
    testWidgets('applies rating + verified-only into ServiceSearchFilters', (
      WidgetTester tester,
    ) async {
      ServiceSearchFilters? applied;
      await pumpApp(
        tester,
        DiscoveryFilterSheet(
          initial: const ServiceSearchFilters(),
          onApply: (ServiceSearchFilters filters) => applied = filters,
        ),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('4.5+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verified professionals only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.ratingMin, 4.5);
      expect(applied!.isTradeVerifiedOnly, isTrue);
    });

    testWidgets('rejects a maximum below the minimum', (
      WidgetTester tester,
    ) async {      bool applied = false;
      await pumpApp(
        tester,
        DiscoveryFilterSheet(
          initial: const ServiceSearchFilters(),
          onApply: (_) => applied = true,
        ),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Min'), '5000');
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '1000');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(applied, isFalse);
      expect(find.text('Maximum must be greater than minimum.'), findsOneWidget);
    });

    testWidgets('applies industry + profession + price + currency', (
      WidgetTester tester,
    ) async {
      ServiceSearchFilters? applied;
      await pumpApp(
        tester,
        DiscoveryFilterSheet(
          initial: const ServiceSearchFilters(),
          onApply: (ServiceSearchFilters filters) => applied = filters,
        ),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(HivorrChip, 'Artisans'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(HivorrChip, 'Plumber'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Min'), '1,000');
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '5000');
      await tester.tap(find.widgetWithText(HivorrChip, 'NGN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.industryId, 'ind-1');
      expect(applied!.professionId, 'prof-9');
      expect(applied!.priceMin, 1000);
      expect(applied!.priceMax, 5000);
      expect(applied!.currencyCode, 'NGN');
    });
  });
}
