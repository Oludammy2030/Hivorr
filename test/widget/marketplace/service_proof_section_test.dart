import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/service_listing_proof.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/service_proof_section.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_grid.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  List<SingleChildWidget> providers({
    required FakeServiceListingRepository repo,
  }) => <SingleChildWidget>[
    Provider<ServiceListingService>.value(
      value: ServiceListingService(repository: repo),
    ),
  ];

  Widget section({required bool isOwner, String? profileSlug}) =>
      ServiceProofSection(
        listingId: 'd1',
        ownerEntityId: 'entity-9',
        isOwner: isOwner,
        profileSlug: profileSlug,
      );

  group('ServiceProofSection', () {
    testWidgets('viewer sees linked proof in server order', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
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
        section(isOwner: false),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proof of work'), findsOneWidget);
      expect(find.byType(PortfolioGrid), findsOneWidget);
      expect(find.text('First proof piece'), findsOneWidget);
      expect(find.text('Second proof piece'), findsOneWidget);
      // Viewer never sees link entries.
      expect(find.text('Add portfolio'), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('owner with no proof sees the Add portfolio entry', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository();
      await pumpApp(
        tester,
        section(isOwner: true),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('No proof linked yet'), findsOneWidget);
      expect(
        find.text(
          'Link portfolio pieces to this service to convert more views.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add portfolio'), findsOneWidget);
    });

    testWidgets('viewer with no proof sees the calm copy without a CTA', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository();
      await pumpApp(
        tester,
        section(isOwner: false),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('No proof linked yet'), findsOneWidget);
      expect(
        find.text(
          'Proof of work will appear here once the professional links it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add portfolio'), findsNothing);
    });

    testWidgets('owner with proof sees the Edit entry', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(id: 'p1'),
              ],
            },
          );
      await pumpApp(
        tester,
        section(isOwner: true),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Add portfolio'), findsNothing);
    });

    testWidgets('profile deep-link shows only with a slug', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(id: 'p1'),
              ],
            },
          );
      await pumpApp(
        tester,
        section(isOwner: false, profileSlug: 'plumber'),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('View full portfolio'), findsOneWidget);
    });

    testWidgets('video, link, and null-media items render placeholders', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                const LinkedPortfolioItem(
                  item: PortfolioItem(
                    id: 'v1',
                    itemType: 'video',
                    title: 'Video walkthrough',
                  ),
                  linkSortOrder: 1,
                ),
                const LinkedPortfolioItem(
                  item: PortfolioItem(
                    id: 'l1',
                    itemType: 'link',
                    title: 'External case study',
                  ),
                  linkSortOrder: 2,
                ),
                const LinkedPortfolioItem(
                  item: PortfolioItem(id: 'n1', title: 'Untitled scan'),
                  linkSortOrder: 3,
                ),
              ],
            },
          );
      await pumpApp(
        tester,
        // The detail screen nests the section in a scroll view; mirror that
        // so tall grids never overflow the test viewport.
        SingleChildScrollView(
          child: section(isOwner: false),
        ),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      // No public media URLs are resolvable here (no portfolio service in
      // the tree), so every tile falls back to its type placeholder —
      // nothing crashes and all three tiles render.
      expect(find.byType(PortfolioGrid), findsOneWidget);
      expect(find.text('Video walkthrough'), findsOneWidget);
      expect(find.text('External case study'), findsOneWidget);
      expect(find.text('Untitled scan'), findsOneWidget);
    });

    testWidgets('failure renders the error state with retry', (
      WidgetTester tester,
    ) async {
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository()
            ..proofError = const ApiException(
              kind: ApiExceptionKind.server,
              message: 'Proof list is unavailable.',
              code: 'PLT999',
            );
      await pumpApp(
        tester,
        section(isOwner: false),
        providers: providers(repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load proof of work'), findsOneWidget);

      // Clearing the fault and retrying recovers to the loaded set.
      repo.proofError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No proof linked yet'), findsOneWidget);
    });

    testWidgets('works without an auth session (signed-out viewer)', (
      WidgetTester tester,
    ) async {
      final FakeAuthProvider auth = FakeAuthProvider(
        initialStatus: AuthStatus.unauthenticated,
      );
      addTearDown(auth.dispose);
      final FakeServiceListingRepository repo =
          FakeServiceListingRepository(
            proofs: <String, List<LinkedPortfolioItem>>{
              'd1': <LinkedPortfolioItem>[
                FakeServiceListingRepository.proof(
                  id: 'p1',
                  title: 'Signed-out visible proof',
                ),
              ],
            },
          );
      await pumpApp(
        tester,
        section(isOwner: false),
        providers: <SingleChildWidget>[
          ...providers(repo: repo),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Signed-out visible proof'), findsOneWidget);
    });
  });
}
