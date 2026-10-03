import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/favorite_toggle_button.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  List<SingleChildWidget> providers(FakeServiceListingRepository repo) =>
      <SingleChildWidget>[
        Provider<ServiceListingService>.value(
          value: ServiceListingService(repository: repo),
        ),
      ];

  group('FavoriteToggleButton', () {
    testWidgets('toggles from outline to filled on tap', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(seed: const []);
      await pumpApp(
        tester,
        const FavoriteToggleButton(listingId: 'listing-1'),
        providers: providers(repo),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byType(FavoriteToggleButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(repo.favorites, contains('listing-1'));
    });

    testWidgets('renders the initial favorited state', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const FavoriteToggleButton(
          listingId: 'listing-1',
          initialFavorited: true,
        ),
        providers: providers(
          FakeServiceListingRepository(seed: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}
