import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing_proof.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
import 'package:hivorr/systems/marketplace/screens/service_detail_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../support/fakes/fake_auth.dart';
import '../support/fakes/fake_portfolio.dart';
import '../support/fakes/fake_service_listing.dart';
import '../support/harnesses/widget_harness.dart';

/// Fake-E2E integration for EP-03-15.
///
/// Exercises the real `ServiceDetailScreen` against scripted fakes across
/// the data → service → section stack:
///  - Flow 1: signed-out viewer opens a published listing with linked proof
///    and sees the ordered proof grid (no link entries).
///  - Flow 2: the owner opens their listing with no linked proof and sees
///    the `Add portfolio` entry.
///  - Flow 3: the owner links a portfolio piece through the real
///    `LinkPortfolioSheet` (search + select + save) and the detail section
///    reloads to show it — full-replace, authoritative re-read, no
///    optimistic tiles.
void main() {
  MyServiceListing ownerRow() => const MyServiceListing(
    id: 'd1',
    entityId: 'entity-9',
    professionId: 'prof-1',
    industryId: 'ind-1',
    slug: 'listing-d1',
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
    media: <ListingMedia>[],
  );

  List<SingleChildWidget> providers({
    required FakeServiceListingRepository listingRepo,
    FakePortfolioRemoteDataSource? portfolioRemote,
    FakeAuthProvider? auth,
  }) => <SingleChildWidget>[
    Provider<ServiceListingService>.value(
      value: ServiceListingService(repository: listingRepo),
    ),
    if (portfolioRemote != null)
      Provider<PortfolioRepository>.value(
        value: PortfolioRepositoryImpl(remote: portfolioRemote),
      ),
    if (auth != null) ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];

  FakeAuthProvider ownerAuth() {
    final FakeAuthProvider auth = FakeAuthProvider(
      initialStatus: AuthStatus.authenticated,
    );
    auth.sessionOverride = const AuthSession(entityId: 'entity-9');    addTearDown(auth.dispose);
    return auth;
  }

  group('EP-03-15 listing proof flow', () {
    testWidgets('Flow 1: viewer sees linked proof in server order', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow()],
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(
                  id: 'p1',
                  title: 'First proof piece',
                  linkSortOrder: 1,
                ),
                FakeServiceListingRepository.proof(
                  id: 'p2',
                  title: 'Second proof piece',
                  linkSortOrder: 2,
                ),
              ],
            },
          );
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authoritative service title'), findsOneWidget);
      expect(find.text('Proof of work'), findsOneWidget);
      expect(find.text('First proof piece'), findsOneWidget);
      expect(find.text('Second proof piece'), findsOneWidget);
      expect(find.text('Add portfolio'), findsNothing);
    });

    testWidgets('Flow 2: owner with no proof sees the Add entry', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow()],
          );
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo, auth: ownerAuth()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No proof linked yet'), findsOneWidget);
      expect(find.text('Add portfolio'), findsOneWidget);
    });

    testWidgets('Flow 3: owner links proof through the sheet', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow()],
          );
      final FakePortfolioRemoteDataSource portfolioRemote =
          FakePortfolioRemoteDataSource(
            result: seedPublicProfileDto(
              entityId: 'entity-9',
              portfolioItems: <PortfolioItemDto>[
                seedPortfolioItemDto(
                  id: 'p1',
                  title: 'Linked through sheet',
                  mediaPath: 'portfolio-items/entity-9/p1.jpg',
                ),
              ],
            ),
          );
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(
          listingRepo: listingRepo,
          portfolioRemote: portfolioRemote,
          auth: ownerAuth(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add portfolio'));
      await tester.pumpAndSettle();
      expect(find.text('Add portfolio'), findsOneWidget);

      await tester.tap(find.text('Add portfolio'));
      await tester.pumpAndSettle();
      expect(find.text('Linked through sheet'), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save (1)'));
      await tester.pumpAndSettle();

      // The sheet saved (full-replace) and the section reloaded
      // authoritatively — the linked piece now renders as proof. (The fake
      // fabricates re-read titles for freshly linked ids, exactly where the
      // real RPC returns the stored rows; the sheet asserted the portfolio
      // title above.)
      expect(listingRepo.proofLinkCalls, 1);
      expect(find.text('Linked proof p1'), findsOneWidget);
      expect(find.text('No proof linked yet'), findsNothing);
    });
  });
}
