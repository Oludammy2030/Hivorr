import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/systems/marketplace/screens/service_listing_form_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/pricing_type_selector.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/fakes/fake_taxonomy.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  ServiceListingProvider listingProvider() {
    // No Supabase client: form list paths never touch media row CRUD.
    final ServiceListingService service = ServiceListingService(
      repository: FakeServiceListingRepository(seed: const []),
    );
    return ServiceListingProvider(service: service);
  }

  TaxonomyProvider taxonomyProvider() =>
      TaxonomyProvider(repository: FakeTaxonomyRepository());

  List<SingleChildWidget> providers(
    ServiceListingProvider listing,
    TaxonomyProvider taxonomy,
  ) =>
      <SingleChildWidget>[
        ChangeNotifierProvider<ServiceListingProvider>.value(value: listing),
        ChangeNotifierProvider<TaxonomyProvider>.value(value: taxonomy),
      ];

  group('ServiceListingFormScreen', () {
    testWidgets('shows profession step first with step indicator', (
      WidgetTester tester,
    ) async {
      final ServiceListingProvider listing = listingProvider();
      final TaxonomyProvider taxonomy = taxonomyProvider();
      addTearDown(listing.dispose);
      addTearDown(taxonomy.dispose);

      await pumpApp(
        tester,
        const ServiceListingFormScreen(),
        providers: providers(listing, taxonomy),
      );
      await tester.pumpAndSettle();

      expect(find.text('New listing'), findsOneWidget);
      expect(find.text('Profession'), findsWidgets);
      expect(find.text('Details'), findsWidgets);
      expect(find.text('Pricing'), findsWidgets);
    });

    testWidgets('PricingTypeSelector selects and reports type', (
      WidgetTester tester,
    ) async {
      String? selected;
      await pumpApp(
        tester,
        PricingTypeSelector(
          selected: 'fixed',
          onSelected: (String v) => selected = v,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fixed price'), findsOneWidget);
      expect(find.text('Hourly'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Per milestone'), findsOneWidget);

      await tester.tap(find.text('Hourly'));
      await tester.pumpAndSettle();
      expect(selected, 'hourly');
    });
  });
}
