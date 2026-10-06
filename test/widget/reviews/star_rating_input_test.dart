import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/reviews/widgets/rating_distribution_bar.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_display.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_input.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('StarRatingInput', () {
    testWidgets('tapping a star reports 1-5 with semantics', (
      WidgetTester tester,
    ) async {
      int? selected;
      await pumpTheme(
        tester,
        StarRatingInput(value: 0, onChanged: (int v) => selected = v),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Rate 3 out of 5'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Rate 3 out of 5'));
      expect(selected, 3);
    });

    testWidgets('disabled input ignores taps', (WidgetTester tester) async {
      int calls = 0;
      await pumpTheme(
        tester,
        StarRatingInput(
          value: 4,
          enabled: false,
          onChanged: (_) => calls++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Rate 5 out of 5'));
      await tester.pump();
      expect(calls, 0);
    });
  });

  group('StarRatingDisplay', () {
    testWidgets('renders value with star icons', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const StarRatingDisplay(rating: 4.5, showValue: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('4.5'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Semantics &&
              (w.properties.label ?? '').contains('Rated 4.5 out of 5'),
        ),
        findsOneWidget,
      );
    });
  });

  group('RatingDistributionBar', () {
    testWidgets('renders rows with counts', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const RatingDistributionBar(
          distribution: <int, int>{1: 0, 2: 0, 3: 0, 4: 1, 5: 1},
          reviewCount: 2,
        ),
      );
      await tester.pumpAndSettle();

      // Star label '1' plus two count cells of 1 (4-star and 5-star).
      expect(find.text('1'), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Semantics &&
              (w.properties.label ?? '').contains(
                'Rating distribution from 2 reviews',
              ),
        ),
        findsOneWidget,
      );
    });
  });
}
