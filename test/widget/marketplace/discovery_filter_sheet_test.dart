import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_filter_sheet.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

/// Compact-select interaction helpers.
///
/// Triggers are tapped by their visible hint text (unique while the option
/// surface is closed); options are tapped by their stable row keys so
/// same-label rows behind the overlay can never match.
Finder option(String label) =>
    find.byKey(ValueKey<String>('hivorr-select-option-$label'));

Future<void> pickOption(
  WidgetTester tester, {
  required String trigger,
  required String optionLabel,
}) async {
  await tester.tap(find.text(trigger));
  await tester.pumpAndSettle();
  await tester.tap(option(optionLabel));
  await tester.pumpAndSettle();
}

void main() {
  const Industry artisans = Industry(
    id: 'ind-1',
    slug: 'artisans',
    name: 'Artisans',
    isActive: true,
    sortOrder: 10,
  );
  const Profession plumber = Profession(
    id: 'prof-9',
    industryId: 'ind-1',
    slug: 'plumber',
    name: 'Plumber',
    isActive: true,
    sortOrder: 10,
  );
  const Industry technology = Industry(
    id: 'ind-2',
    slug: 'technology',
    name: 'Technology',
    isActive: true,
    sortOrder: 20,
  );
  const Profession developer = Profession(
    id: 'prof-10',
    industryId: 'ind-2',
    slug: 'software-developer',
    name: 'Software Developer',
    isActive: true,
    sortOrder: 10,
  );

  TaxonomyProvider taxonomy() {
    final TaxonomyProvider provider = TaxonomyProvider(
      repository: FakeTaxonomyRepository(
        industries: const <Industry>[artisans],
        professionsByIndustry: const <String, List<Profession>>{
          'ind-1': <Profession>[plumber],
        },
      ),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  TaxonomyProvider twoIndustries() {
    final TaxonomyProvider provider = TaxonomyProvider(
      repository: FakeTaxonomyRepository(
        industries: const <Industry>[artisans, technology],
        professionsByIndustry: const <String, List<Profession>>{
          'ind-1': <Profession>[plumber],
          'ind-2': <Profession>[developer],
        },
      ),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    TaxonomyProvider taxonomyProvider, {
    ServiceSearchFilters initial = const ServiceSearchFilters(),
    required ValueChanged<ServiceSearchFilters> onApply,
  }) {
    return pumpApp(
      tester,
      DiscoveryFilterSheet(initial: initial, onApply: onApply),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TaxonomyProvider>.value(
          value: taxonomyProvider,
        ),
      ],
    );
  }

  group('DiscoveryFilterSheet', () {
    testWidgets('applies rating + verified-only into ServiceSearchFilters', (
      WidgetTester tester,
    ) async {
      ServiceSearchFilters? applied;
      await pumpSheet(
        tester,
        taxonomy(),
        onApply: (ServiceSearchFilters filters) => applied = filters,
      );
      await tester.pumpAndSettle();

      await pickOption(tester, trigger: 'Any rating', optionLabel: '4.5+');
      expect(find.text('4.5+'), findsOneWidget);
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
    ) async {
      bool applied = false;
      await pumpSheet(
        tester,
        taxonomy(),
        onApply: (_) => applied = true,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Min'), '5000');
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '1000');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(applied, isFalse);
      expect(
        find.text('Maximum must be greater than minimum.'),
        findsOneWidget,
      );
    });

    testWidgets('applies industry + profession + price + currency', (
      WidgetTester tester,
    ) async {
      ServiceSearchFilters? applied;
      await pumpSheet(
        tester,
        taxonomy(),
        onApply: (ServiceSearchFilters filters) => applied = filters,
      );
      await tester.pumpAndSettle();

      await pickOption(
        tester,
        trigger: 'Select industry',
        optionLabel: 'Artisans',
      );
      // The dependent profession select unlocks once the industry loads.
      await pickOption(
        tester,
        trigger: 'Select profession',
        optionLabel: 'Plumber',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Min'), '1,000');
      await tester.enterText(find.widgetWithText(TextField, 'Max'), '5000');
      await pickOption(
        tester,
        trigger: 'Any currency',
        optionLabel: 'NGN ₦',
      );
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.industryId, 'ind-1');
      expect(applied!.professionId, 'prof-9');
      expect(applied!.priceMin, 1000);
      expect(applied!.priceMax, 5000);
      expect(applied!.currencyCode, 'NGN');
    });

    testWidgets('changing industry clears an incompatible profession', (
      WidgetTester tester,
    ) async {
      ServiceSearchFilters? applied;
      await pumpSheet(
        tester,
        twoIndustries(),
        onApply: (ServiceSearchFilters filters) => applied = filters,
      );
      await tester.pumpAndSettle();

      await pickOption(
        tester,
        trigger: 'Select industry',
        optionLabel: 'Artisans',
      );
      await pickOption(
        tester,
        trigger: 'Select profession',
        optionLabel: 'Plumber',
      );
      // Switching industries must invalidate the profession selection.
      await pickOption(tester, trigger: 'Artisans', optionLabel: 'Technology');
      expect(find.text('Select profession'), findsOneWidget);
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.industryId, 'ind-2');
      expect(applied!.professionId, isNull);
    });

    testWidgets('profession stays disabled until an industry is chosen', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, taxonomy(), onApply: (_) {});
      await tester.pumpAndSettle();

      expect(find.text('Select industry first'), findsOneWidget);
      await tester.tap(find.text('Select industry first'));
      await tester.pumpAndSettle();
      // No option surface opened: the reset row never renders.
      expect(option('All professions'), findsNothing);
    });

    testWidgets('show Cancel dismisses the mobile sheet without applying', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const SizedBox.shrink(),
        width: 390,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TaxonomyProvider>.value(
            value: taxonomy(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(SizedBox));
      ServiceSearchFilters? result = const ServiceSearchFilters(
        ratingMin: 9,
      );
      unawaited(
        DiscoveryFilterSheet.show(
          context: context,
          initial: const ServiceSearchFilters(),
        ).then((ServiceSearchFilters? value) => result = value),
      );
      await tester.pumpAndSettle();
      expect(find.text('Filter services'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Filter services'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('mobile sheet scrolls far enough to apply', (
      WidgetTester tester,
    ) async {
      // The sheet content is taller than small viewports, so the Apply
      // button must be reachable by scrolling within the sheet.
      for (final Size viewport in <Size>[
        const Size(390, 844),
        const Size(360, 640),
        const Size(320, 568),
      ]) {
        await pumpScreen(
          tester,
          const SizedBox.shrink(key: ValueKey<String>('sheet-host')),
          width: viewport.width,
          height: viewport.height,
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<TaxonomyProvider>.value(
              value: taxonomy(),
            ),
          ],
        );
        await tester.pumpAndSettle();

        final BuildContext context = tester.element(
          find.byKey(const ValueKey<String>('sheet-host')),
        );
        ServiceSearchFilters? result;
        unawaited(
          DiscoveryFilterSheet.show(
            context: context,
            initial: const ServiceSearchFilters(),
          ).then((ServiceSearchFilters? value) => result = value),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final Finder apply = find.text('Apply filters');
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        final Rect box = tester.getRect(apply);
        expect(box.top, greaterThanOrEqualTo(0));
        expect(box.bottom, lessThanOrEqualTo(viewport.height));
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(result, isNotNull);
      }
    });
  });
}
