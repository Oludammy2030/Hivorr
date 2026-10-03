import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_service_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  List<SingleChildWidget> providers() => <SingleChildWidget>[
    Provider<ServiceListingService>.value(
      value: ServiceListingService(
        repository: FakeServiceListingRepository(seed: const []),
      ),
    ),
  ];

  group('DiscoveryServiceCard', () {
    testWidgets('renders title, price, rating, and badges verbatim', (
      WidgetTester tester,
    ) async {
      final ServiceListing listing = rankedListing(
        id: 's1',
        avgRating: 4.5,
        reviewCount: 3,
      );

      await pumpApp(
        tester,
        DiscoveryServiceCard(listing: listing),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      expect(find.text(listing.title), findsOneWidget);
      // Price line: NGN 5,000 – 15,000.
      expect(find.textContaining('NGN'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.textContaining('3 reviews'), findsOneWidget);
      expect(find.text('Trade verified'), findsOneWidget);
      expect(find.text('Plumber'), findsOneWidget);
    });

    testWidgets('tap opens the detail handler', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await pumpApp(
        tester,
        DiscoveryServiceCard(
          listing: rankedListing(id: 's1'),
          onTap: () => tapped = true,
        ),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DiscoveryServiceCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('hides the favorite heart when showFavorite is false', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        DiscoveryServiceCard(
          listing: rankedListing(id: 's1'),
          showFavorite: false,
        ),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Save to favorites'), findsNothing);
    });

    testWidgets('renders custom pricing without crashing', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        DiscoveryServiceCard(
          listing: rankedListing(
            id: 's9',
            pricingType: 'custom',
            priceMin: null,
            priceMax: null,
          ),
          showFavorite: false,
        ),
        providers: providers(),
      );
      await tester.pumpAndSettle();

      expect(find.text('NGN Custom quote'), findsOneWidget);
      expect(find.text('Custom quote'), findsOneWidget);
    });
  });
}
