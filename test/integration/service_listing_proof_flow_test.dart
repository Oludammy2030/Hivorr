import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing_proof.dart';
import 'package:hivorr/data/models/portfolio_item_dto.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
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
    auth.sessionOverride = const AuthSession(entityId: 'entity-9');
    addTearDown(auth.dispose);
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
          FakeServiceListingRepository(seed: <MyServiceListing>[ownerRow()]);
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
          FakeServiceListingRepository(seed: <MyServiceListing>[ownerRow()]);
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

  // ─── EP-03-20 VP10 — DoD extension (plan §6.4) ──────────────────────────
  // DoD-VP10a/b/c/d/e/f deepen the existing Flow 1-3 coverage: payload order
  // verbatim, empty-state + owner CTA, owner-only link guard, narrow-viewport
  // render checks, and the responsive no-overflow matrix (390/600/1024/1280).
  group('EP-03-20 VP10 — listing detail proof linkage (DoD)', () {
    /// Pumps the detail screen at a phone-sized 390×844 viewport so the
    /// proof grid lays out single-column (mobile band < 600dp) and proof
    /// order is readable on the y axis.
    Future<void> pumpPhone(
      WidgetTester tester,
      Widget child, {
      List<SingleChildWidget>? providers,
    }) async => pumpApp(tester, child, providers: providers);

    testWidgets('DoD-VP10a: proof grid renders in payload order verbatim '
        '(client never re-sorts by linkSortOrder)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Arrange: the payload array is deliberately UNSORTED with respect to
      // `link_sort_order` — p1 carries the higher linkSortOrder yet comes
      // first in the server payload. The client must render the payload
      // order verbatim (server order is authoritative, AGENT.md Rule 4).
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow()],
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(
                  id: 'p1',
                  title: 'Payload-first piece',
                  linkSortOrder: 2,
                ),
                FakeServiceListingRepository.proof(
                  id: 'p2',
                  title: 'Payload-second piece',
                  linkSortOrder: 1,
                ),
              ],
            },
          );

      // Act: render the detail screen for a signed-out viewer.
      await pumpPhone(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo),
      );
      await tester.pumpAndSettle();

      // Assert: both pieces render, in PAYLOAD order — the higher
      // linkSortOrder piece stays first because the payload said so.
      expect(find.text('Payload-first piece'), findsOneWidget);
      expect(find.text('Payload-second piece'), findsOneWidget);
      final Offset firstTop = tester.getTopLeft(
        find.text('Payload-first piece'),
      );
      final Offset secondTop = tester.getTopLeft(
        find.text('Payload-second piece'),
      );
      expect(
        firstTop.dy,
        lessThan(secondTop.dy),
        reason:
            'render order must mirror the server payload order verbatim, '
            'not link_sort_order',
      );
      // The read reached the repository exactly once (no client-side reshuffle
      // passes, no optimistic reorder).
      expect(listingRepo.proofListCalls, 1);
    });

    testWidgets('DoD-VP10b: unlinked listing shows the HivorrEmptyState and '
        'the owner CTA, with no owner CTA for non-owners', (
      WidgetTester tester,
    ) async {
      // Arrange: the listing has no linked proof at all.
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(seed: <MyServiceListing>[ownerRow()]);

      // Act 1: the owner opens the detail screen.
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo, auth: ownerAuth()),
      );
      await tester.pumpAndSettle();

      // Assert 1: the shared empty state renders with the owner-only
      // "Add portfolio" affordance.
      expect(find.byType(HivorrEmptyState), findsWidgets);
      expect(find.text('No proof linked yet'), findsOneWidget);
      expect(find.text('Add portfolio'), findsOneWidget);

      // Act 2: a signed-out viewer opens the same listing.
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo),
      );
      await tester.pumpAndSettle();

      // Assert 2: still the empty state, but no owner affordance is offered.
      expect(find.byType(HivorrEmptyState), findsWidgets);
      expect(find.text('No proof linked yet'), findsOneWidget);
      expect(find.text('Add portfolio'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('DoD-VP10c: non-owner linkProofs is refused with PLT001', () async {
      // Arrange: the server rejects the write (owner-only RPC).
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(seed: <MyServiceListing>[ownerRow()])
            ..proofError = const ApiException(
              kind: ApiExceptionKind.forbidden,
              message: 'Only the listing owner may modify linked proof.',
              code: 'PLT001',
            );
      final ServiceListingService service = ServiceListingService(
        repository: listingRepo,
      );

      // Act & Assert: the typed ownership refusal propagates — the client
      // never links proof locally (storage/RPC ownership is server-side).
      await expectLater(
        service.linkProofs(listingId: 'd1', portfolioItemIds: <String>['p1']),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT001')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.forbidden,
              ),
        ),
      );
      expect(
        listingRepo.proofLinkCalls,
        1,
        reason: 'the write attempt reached the seam exactly once',
      );
    });

    testWidgets('DoD-VP10e: screen renders the refusal state without owner '
        'affordances (no crash)', (WidgetTester tester) async {
      // Arrange: proof reads fail the same way (server-side denial).
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
              seed: <MyServiceListing>[ownerRow()],
              proofs: <String, List<LinkedPortfolioItem>>{
                'd1': <LinkedPortfolioItem>[
                  FakeServiceListingRepository.proof(id: 'p1'),
                ],
              },
            )
            ..proofError = const ApiException(
              kind: ApiExceptionKind.forbidden,
              message: 'Only the listing owner may modify linked proof.',
              code: 'PLT001',
            );

      // Act: a signed-out (non-owner) viewer opens the detail screen.
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo),
      );
      await tester.pumpAndSettle();

      // Assert: the section degrades to its error state with retry, the
      // owner-only affordances are absent, and no layout/render exception
      // was thrown.
      expect(find.text('Could not load proof of work'), findsOneWidget);
      expect(find.text('Add portfolio'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DoD-VP10d: owner detail screen renders clean at 390px '
        '(phone viewport, no exceptions)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Arrange: published listing with two linked proofs + owner auth.
      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow()],
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(
                  id: 'p1',
                  title: 'Narrow proof one',
                ),
                FakeServiceListingRepository.proof(
                  id: 'p2',
                  title: 'Narrow proof two',
                ),
              ],
            },
          );

      // Act: render and settle at phone width.
      await pumpApp(
        tester,
        const ServiceDetailScreen(listingId: 'd1'),
        providers: providers(listingRepo: listingRepo, auth: ownerAuth()),
      );
      await tester.pumpAndSettle();
      // Scroll through the whole page so every section gets built + laid out
      // at 390px (overflow bugs only surface when reached).
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2400),
      );
      await tester.pumpAndSettle();

      // Assert: key sections rendered, zero exceptions.
      expect(tester.takeException(), isNull);
      expect(find.text('Authoritative service title'), findsOneWidget);
      expect(find.text('Proof of work'), findsOneWidget);
      expect(find.text('Narrow proof one'), findsOneWidget);
      expect(find.text('Narrow proof two'), findsOneWidget);
      expect(listingRepo.proofListCalls, 1);
    });

    testWidgets('DoD-VP10f: detail screen renders without overflow across the '
        'responsive matrix (390/600/1024/1280)', (WidgetTester tester) async {
      // UI-02 / decision D2: the responsive no-overflow matrix substitutes for
      // goldens. 390 px is asserted at dpr 3 (physical 1170) as the DoD
      // requires; the wider bands run at dpr 1.
      const List<List<num>> matrix = <List<num>>[
        <num>[390, 3],
        <num>[600, 1],
        <num>[1024, 1],
        <num>[1280, 1],
      ];

      final FakeServiceListingRepository listingRepo =
          FakeServiceListingRepository(
            seed: <MyServiceListing>[ownerRow()],
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(id: 'p1'),
              ],
            },
          );

      for (final List<num> band in matrix) {
        final double width = band[0].toDouble();
        final double dpr = band[1].toDouble();
        tester.view.physicalSize = Size(width * dpr, 844 * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);

        await pumpApp(
          tester,
          const ServiceDetailScreen(listingId: 'd1'),
          providers: providers(listingRepo: listingRepo, auth: ownerAuth()),
        );
        await tester.pumpAndSettle();
        // Walk the whole page so every section is built and laid out at this
        // viewport (overflow only surfaces once reached).
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2400),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(ServiceDetailScreen),
          findsOneWidget,
          reason: 'screen must render at ${width.toInt()}px',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow/exception at ${width.toInt()}px (dpr $dpr)',
        );
      }
    });
  });
}
