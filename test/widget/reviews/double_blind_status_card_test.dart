import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/systems/reviews/widgets/double_blind_status_card.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_input.dart';

import '../../support/harnesses/widget_harness.dart';

ServiceReview row({
  String id = 'r1',
  int rating = 5,
  String comment = 'Excellent delivery and communication',
}) => ServiceReview(
  id: id,
  contractId: 'c1',
  serviceListingId: 'listing-1',
  reviewerEntityId: 'client-1',
  revieweeEntityId: 'pro-1',
  professionId: 'profession-1',
  rating: rating,
  comment: comment,
  isRevealed: true,
);

MyReviewStatus awaitingYours() => const MyReviewStatus(
  contractId: 'c1',
  youHaveSubmitted: false,
  reviewCount: 0,
);

MyReviewStatus awaitingCounterparty() => MyReviewStatus(
  contractId: 'c1',
  youHaveSubmitted: true,
  yourReview: const ServiceReview(
    id: 'r1',
    contractId: 'c1',
    serviceListingId: 'listing-1',
    reviewerEntityId: 'client-1',
    revieweeEntityId: 'pro-1',
    professionId: 'profession-1',
    rating: 5,
    comment: 'Excellent delivery and communication',
    isRevealed: false,
  ),
  reviewCount: 0,
);

void main() {
  group('DoubleBlindStatusCard', () {
    testWidgets('awaiting_yours shows submit CTA', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        DoubleBlindStatusCard(
          status: awaitingYours(),
          onWriteReview: () => tapped = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awaiting your review'), findsOneWidget);
      expect(find.text('Write a review'), findsOneWidget);
      await tester.tap(find.text('Write a review'));
      expect(tapped, isTrue);
    });

    testWidgets('awaiting_counterparty hides ratings (no oracle)', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        DoubleBlindStatusCard(status: awaitingCounterparty()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for the other party'), findsOneWidget);
      // The viewer's own unrevealed rating must not render as stars/text.
      expect(find.byType(StarRatingInput), findsNothing);
      expect(find.text('5'), findsNothing);
      expect(find.text('Excellent delivery and communication'), findsNothing);
      expect(find.byType(HivorrBadge), findsWidgets);
    });

    testWidgets('revealed shows both reviews with badge', (
      WidgetTester tester,
    ) async {
      final MyReviewStatus status = MyReviewStatus(
        contractId: 'c1',
        youHaveSubmitted: true,
        revealedReviews: <ServiceReview>[
          row(id: 'r1', rating: 5),
          row(id: 'r2', rating: 4, comment: 'Good work overall today'),
        ],
        reviewCount: 2,
      );
      await pumpTheme(
        tester,
        SingleChildScrollView(
          child: DoubleBlindStatusCard(status: status),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revealed'), findsOneWidget);
      expect(
        find.text('Excellent delivery and communication'),
        findsOneWidget,
      );
      expect(find.text('Good work overall today'), findsOneWidget);
    });

    testWidgets('stateFor derives verbatim server fields', (
      WidgetTester tester,
    ) async {
      expect(
        DoubleBlindStatusCard.stateFor(awaitingYours()),
        DoubleBlindState.awaitingYours,
      );
      expect(
        DoubleBlindStatusCard.stateFor(awaitingCounterparty()),
        DoubleBlindState.awaitingCounterparty,
      );
    });
  });
}
