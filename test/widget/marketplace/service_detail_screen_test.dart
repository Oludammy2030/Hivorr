import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/systems/marketplace/screens/service_detail_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/service_media_carousel.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  List<SingleChildWidget> providers({
    required FakeServiceListingRepository repo,
    AuthProvider? auth,
  }) => <SingleChildWidget>[
    Provider<ServiceListingService>.value(
      value: ServiceListingService(repository: repo),
    ),
    if (auth != null) ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];

  MyServiceListing ownerRow({
    required String id,
    String entityId = 'entity-9',
    List<ListingMedia> media = const <ListingMedia>[],
  }) => MyServiceListing(
    id: id,
    entityId: entityId,
    professionId: 'prof-1',
    industryId: 'ind-1',
    slug: 'listing-$id',
    title: 'Authoritative service title',
    description:
        'Full home plumbing inspection, leak repair, and fixture replacement with a written service report and warranty.',
    status: 'published',
    pricingType: 'fixed',
    priceMin: 5000,
    priceMax: 15000,
    currencyCode: 'NGN',
    avgRating: 4.5,
    reviewCount: 3,
    isTradeVerifiedCache: true,
    professionSlug: 'plumber',
    professionName: 'Plumber',
    industrySlug: 'artisans',
    industryName: 'Artisans',
    media: media,
  );

  group('ServiceDetailScreen', () {
    testWidgets('paints instantly and holds it when no detail seam exists', (
      WidgetTester tester,
    ) async {
      // No ServiceListingService in the tree: the screen keeps the
      // instant-paint row and degrades media gracefully instead of crashing.
      final ServiceListing initial = rankedListing(
        id: 'd1',
        title: 'Instant paint title',
      );
      await pumpApp(
        tester,
        ServiceDetailScreen(listingId: 'd1', initialListing: initial),
        providers: const <SingleChildWidget>[],
      );
      await tester.pumpAndSettle();

      expect(find.text('Instant paint title'), findsOneWidget);
      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('upgrades the instant row to the authoritative row', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow(id: 'd1')],
          );
      final ServiceListing initial = rankedListing(
        id: 'd1',
        title: 'Instant paint title',
      );
      await pumpApp(
        tester,
        ServiceDetailScreen(listingId: 'd1', initialListing: initial),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authoritative service title'), findsOneWidget);
      expect(find.text('Instant paint title'), findsNothing);
    });

    testWidgets('authoritative media renders the carousel with cover', (
      WidgetTester tester,
    ) async {
      const List<ListingMedia> media = <ListingMedia>[
        ListingMedia(
          id: 'm1',
          storagePath: 'entity-9/d1/cover.jpg',
          mimeType: 'image/jpeg',
          sortOrder: 0,
        ),
        ListingMedia(
          id: 'm2',
          storagePath: 'entity-9/d1/second.jpg',
          mimeType: 'image/jpeg',
          sortOrder: 1,
        ),
      ];
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow(id: 'd1', media: media)],
          );
      await pumpApp(
        tester,
        ServiceDetailScreen(
          listingId: 'd1',
          initialListing: rankedListing(id: 'd1'),
        ),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ServiceMediaCarousel), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets('unknown listing shows the not-found empty state', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(seed: const [])
            ..getListingError = const ApiException(
              kind: ApiExceptionKind.notFound,
              message: 'Listing not found.',
              code: 'PLT004',
            );
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'missing'),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Listing not found'), findsOneWidget);
      expect(find.text('Browse services'), findsOneWidget);
    });

    testWidgets('owner sees a disabled CTA with self-hire guidance', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow(id: 'd1')],
          );
      final FakeAuthProvider auth = FakeAuthProvider(
        initialStatus: AuthStatus.authenticated,
      );
      auth.sessionOverride = const AuthSession(entityId: 'entity-9');
      addTearDown(auth.dispose);

      await pumpApp(
        tester,
        ServiceDetailScreen(
          listingId: 'd1',
          initialListing: rankedListing(id: 'd1', entityId: 'entity-9'),
        ),
        providers: providers(repo: repo, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book / Request proposal'), findsOneWidget);
      expect(find.textContaining('cannot hire yourself'), findsOneWidget);
    });
  });
}
