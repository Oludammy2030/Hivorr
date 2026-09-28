import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/marketplace/screens/my_listings_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/service_listing_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  ServiceListingProvider providerWith(FakeServiceListingRepository repo) {
    // No Supabase client: list paths never touch media row CRUD, so the
    // service runs without a networked auth client (no GoTrue timers).
    final ServiceListingService service = ServiceListingService(
      repository: repo,
    );
    return ServiceListingProvider(service: service);
  }

  List<SingleChildWidget> providers(ServiceListingProvider provider) =>
      <SingleChildWidget>[
        ChangeNotifierProvider<ServiceListingProvider>.value(value: provider),
      ];

  group('MyListingsScreen', () {
    testWidgets('shows empty state with create action when no listings', (
      WidgetTester tester,
    ) async {
      final ServiceListingProvider provider = providerWith(
        FakeServiceListingRepository(seed: const []),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const MyListingsScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('No listings yet'), findsOneWidget);
      expect(find.text('Create listing'), findsWidgets);
    });

    testWidgets('renders one card per listing with status + filter chips', (
      WidgetTester tester,
    ) async {
      final ServiceListingProvider provider = providerWith(
        FakeServiceListingRepository(
          seed: <MyServiceListing>[
            FakeServiceListingRepository.listing(
              id: 'listing-1',
              status: 'published',
            ),
            FakeServiceListingRepository.listing(
              id: 'listing-2',
              status: 'draft',
            ),
          ],
        ),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const MyListingsScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ServiceListingCard), findsNWidgets(2));
      expect(find.text('All'), findsOneWidget);
      // 'draft' appears twice (filter chip + status badge); assert at least
      // chip + card render without throwing.
      expect(find.text('draft'), findsWidgets);
      expect(find.text('published'), findsWidgets);
    });

    testWidgets('status chip filters via p_status', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo = FakeServiceListingRepository(
        seed: <MyServiceListing>[
          FakeServiceListingRepository.listing(id: 'l1', status: 'draft'),
        ],
      );
      final ServiceListingProvider provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const MyListingsScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('published'));
      await tester.pumpAndSettle();

      expect(repo.lastStatus, 'published');
    });

    testWidgets('screen mounts without throwing on fast fakes', (
      WidgetTester tester,
    ) async {
      final ServiceListingProvider provider = providerWith(
        FakeServiceListingRepository(seed: const []),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const MyListingsScreen(),
        providers: providers(provider),
      );
      await tester.pump();
      expect(find.byType(MyListingsScreen), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('settles to empty (no lingering loading/error)', (
      WidgetTester tester,
    ) async {
      final ServiceListingProvider provider = providerWith(
        FakeServiceListingRepository(seed: const []),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const MyListingsScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HivorrLoadingState), findsNothing);
      expect(find.byType(HivorrErrorState), findsNothing);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
