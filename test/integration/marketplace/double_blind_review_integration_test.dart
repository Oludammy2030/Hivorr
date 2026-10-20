// Run: flutter test test/integration/marketplace/double_blind_review_integration_test.dart
//
// EP-03-20 VP7 — Double-blind review linkage. Composes the REAL
// ServiceReviewRepositoryImpl → ServiceReviewService → ServiceReviewProvider
// over FakeServiceReviewRemoteDataSource (which mirrors the server blind rule:
// two rows for a contract flip both `is_revealed=true` atomically). Asserts
// the no-oracle posture (pre-reveal get_for_listing returns only revealed),
// duplicate-submit PLT005, and the DoubleBlindStatusCard lifecycle states.
// Also source-scans the app wiring so the provider is actually registered.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/data/repositories/service_review_repository_impl.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';
import 'package:hivorr/systems/reviews/widgets/double_blind_status_card.dart';

import '../../support/fakes/fake_service_review.dart';
import '../../support/harnesses/widget_harness.dart';

/// Builds the provider over the fake review data source.
({ServiceReviewProvider provider, FakeServiceReviewRemoteDataSource remote})
_build({String viewerId = 'client-1'}) {
  final FakeServiceReviewRemoteDataSource remote =
      FakeServiceReviewRemoteDataSource(viewerId: viewerId);
  final ServiceReviewService service = ServiceReviewService(
    repository: ServiceReviewRepositoryImpl(remote: remote),
  );
  return (provider: ServiceReviewProvider(service: service), remote: remote);
}

/// Minimal revealed review for widget-state assertions.
ServiceReview _revealedReview(String id, {int rating = 5, String? comment}) =>
    ServiceReview(
      id: id,
      contractId: 'c1',
      serviceListingId: 'listing-1',
      reviewerEntityId: 'client-1',
      revieweeEntityId: 'pro-1',
      professionId: 'profession-1',
      rating: rating,
      comment: comment,
      isRevealed: true,
      revealedAt: DateTime.utc(2026, 9, 26),
    );

void main() {
  group('EP-03-20 VP7 — double-blind review linkage', () {
    test(
      'DoD-VP7a: one submit stays hidden until both submit (no oracle)',
      () async {
        // Arrange: the client submits first.
        final ({
          ServiceReviewProvider provider,
          FakeServiceReviewRemoteDataSource remote,
        })
        built = _build();

        // Act: client submits a review.
        await built.provider.submit(contractId: 'c1', rating: 5);
        final MyReviewStatus? afterOne = built.provider.myStatusFor('c1');

        // Assert: the client sees their own submission; the counterparty's is
        // invisible (no timing oracle).
        expect(afterOne, isNotNull);
        expect(afterOne!.youHaveSubmitted, isTrue);
        expect(
          afterOne.revealedReviews,
          isEmpty,
          reason: 'counterparty review must stay hidden pre-reveal',
        );
        expect(afterOne.isRevealed, isFalse);
      },
    );

    test('DoD-VP7b: second submit reveals both atomically', () async {
      // Arrange: one shared fake so both reviewers hit the same contract rows.
      final FakeServiceReviewRemoteDataSource shared =
          FakeServiceReviewRemoteDataSource(viewerId: 'client-1');
      final ServiceReviewService service = ServiceReviewService(
        repository: ServiceReviewRepositoryImpl(remote: shared),
      );
      final ServiceReviewProvider provider = ServiceReviewProvider(
        service: service,
      );
      addTearDown(provider.dispose);

      // Act: client submits, then the pro submits (viewer switched).
      await provider.submit(contractId: 'c1', rating: 5);
      shared.viewerId = 'pro-1';
      await provider.submit(contractId: 'c1', rating: 4);

      // Assert: both rows flipped to revealed atomically (server rule).
      final MyReviewStatus? status = provider.myStatusFor('c1');
      expect(status, isNotNull);
      expect(status!.youHaveSubmitted, isTrue);
      expect(status.revealedReviews.length, 2);
      expect(status.isRevealed, isTrue);
      expect(
        shared.rows.every((Map<String, dynamic> r) => r['is_revealed'] == true),
        isTrue,
        reason: 'both rows reveal atomically once two exist',
      );
    });

    test(
      'DoD-VP7c: pre-reveal get_for_listing returns only revealed rows',
      () async {
        // Arrange: a single unrevealed submission on a listing.
        final FakeServiceReviewRemoteDataSource remote =
            FakeServiceReviewRemoteDataSource();
        final ServiceReviewService service = ServiceReviewService(
          repository: ServiceReviewRepositoryImpl(remote: remote),
        );
        final ServiceReviewProvider provider = ServiceReviewProvider(
          service: service,
        );
        addTearDown(provider.dispose);
        await provider.submit(contractId: 'c1', rating: 5);

        // Act: load the listing page (no reveal yet).
        await provider.loadForListing(
          listingId: 'listing-1',
          professionalEntityId: 'pro-1',
          professionId: 'profession-1',
        );

        // Assert: no oracle — the unrevealed row is not exposed on the listing.
        expect(provider.listingReviews, isEmpty);
        expect(provider.isListingEmpty, isTrue);
        expect(remote.getForListingCalls, 1);
      },
    );

    test('DoD-VP7d: duplicate submit is refused with PLT005', () async {
      // Arrange: the client has already submitted.
      final ({
        ServiceReviewProvider provider,
        FakeServiceReviewRemoteDataSource remote,
      })
      built = _build();
      await built.provider.submit(contractId: 'c1', rating: 5);

      // Act & Assert: a second submit from the same reviewer conflicts.
      await expectLater(
        built.provider.submit(contractId: 'c1', rating: 3),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT005',
          ),
        ),
      );
    });

    testWidgets(
      'DoD-VP7e: DoubleBlindStatusCard renders the 3 lifecycle states',
      (WidgetTester tester) async {
        // awaitingYours — nothing submitted yet.
        await pumpTheme(
          tester,
          DoubleBlindStatusCard(
            status: const MyReviewStatus(
              contractId: 'c1',
              youHaveSubmitted: false,
              reviewCount: 0,
            ),
            onWriteReview: () {},
          ),
        );
        expect(find.text('Awaiting your review'), findsOneWidget);
        expect(find.text('Write a review'), findsOneWidget);

        // awaitingCounterparty — viewer submitted, reveal pending.
        await pumpTheme(
          tester,
          const DoubleBlindStatusCard(
            status: MyReviewStatus(
              contractId: 'c1',
              youHaveSubmitted: true,
              reviewCount: 0,
            ),
          ),
        );
        expect(find.text('Waiting for the other party'), findsOneWidget);
        expect(find.text('Submitted'), findsOneWidget);

        // revealed — both reviews exposed.
        await pumpTheme(
          tester,
          DoubleBlindStatusCard(
            status: MyReviewStatus(
              contractId: 'c1',
              youHaveSubmitted: true,
              revealedReviews: <ServiceReview>[
                _revealedReview('r1', rating: 5, comment: 'Excellent work.'),
                _revealedReview('r2', rating: 4, comment: 'Solid delivery.'),
              ],
              reviewCount: 2,
            ),
          ),
        );
        expect(find.text('Revealed'), findsOneWidget);
        expect(find.text('Excellent work.'), findsOneWidget);
        expect(find.text('Solid delivery.'), findsOneWidget);
        expect(
          DoubleBlindStatusCard.stateFor(
            const MyReviewStatus(
              contractId: 'c1',
              youHaveSubmitted: true,
              reviewCount: 0,
            ),
          ),
          DoubleBlindState.awaitingCounterparty,
        );
      },
    );

    test('DoD-VP7f: app wiring registers ServiceReviewProvider', () {
      // Source-scan the bootstrap glue so the provider is actually wired into
      // the widget tree (guards the A2 silent-catch regression).
      final String appDart = File('lib/app/app.dart').readAsStringSync();
      final String bootstrapDart = File(
        'lib/app/app_bootstrap.dart',
      ).readAsStringSync();

      expect(
        appDart.contains('ChangeNotifierProvider<ServiceReviewProvider>'),
        isTrue,
        reason: 'app.dart must register ServiceReviewProvider',
      );
      expect(
        bootstrapDart.contains('registerServiceReviewLayer'),
        isTrue,
        reason: 'app_bootstrap.dart must call registerServiceReviewLayer',
      );
    });
  });
}
