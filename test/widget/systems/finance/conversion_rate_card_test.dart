import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/widgets/conversion_rate_card.dart';

import '../../../support/harnesses/widget_harness.dart';

/// Widget coverage for [ConversionRateCard] (EP-02-15 TT-10 ≥8): the trusted
/// directed + inverse rates, the loading and fail-closed unavailable states,
/// the retry hook, the placeholder while no pair/amount is active, and the
/// AppTheme-token styling (no raw colors — AGENT.md Rule 5).
void main() {
  Future<void> pumpCard(WidgetTester tester, ConversionRateCard card) async {
    await pumpTheme(tester, card);
  }

  group('ConversionRateCard loaded state', () {
    testWidgets('renders the directed rate copy', (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: 0.0007,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: false,
          isUnavailable: false,
        ),
      );

      expect(find.text('1 NGN = 0.0007 USD'), findsOneWidget);
    });

    testWidgets('renders the guarded inverse rate copy',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: 0.0007,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: false,
          isUnavailable: false,
        ),
      );

      expect(find.text('1 USD = 1428.57 NGN'), findsOneWidget);
    });

    testWidgets('labels the source as a platform rate',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: 1.28,
          fromCurrency: 'USD',
          toCurrency: 'GHS',
          isLoading: false,
          isUnavailable: false,
        ),
      );

      expect(find.text('Platform rate'), findsOneWidget);
    });

    testWidgets('styles the directed rate with the theme primary token',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const ConversionRateCard(
          rate: 0.0007,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: false,
          isUnavailable: false,
        ),
      );
      final BuildContext context = tester.element(find.byType(ConversionRateCard));

      expect(find.text('Rate'), findsOneWidget);
      expect(
        find
            .text('1 NGN = 0.0007 USD')
            .evaluate()
            .single
            .widget, isA<Text>(),
      );
      final Text rateText =
          tester.widget<Text>(find.text('1 NGN = 0.0007 USD'));
      expect(
        rateText.style?.color,
        Theme.of(context).colorScheme.primary,
      );
    });
  });

  group('ConversionRateCard transition states', () {
    testWidgets('loading shows the branded loading state',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: null,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: true,
          isUnavailable: false,
        ),
      );

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      expect(find.text('Fetching rate...'), findsOneWidget);
    });

    testWidgets('unavailable shows the fail-closed error state',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: null,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: false,
          isUnavailable: true,
        ),
      );

      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(find.text('Rate unavailable for this pair'), findsOneWidget);
    });

    testWidgets('retry fires the retry callback from the unavailable state',
        (WidgetTester tester) async {
      int retries = 0;
      await pumpCard(
        tester,
        ConversionRateCard(
          rate: null,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: false,
          isUnavailable: true,
          onRetry: () => retries++,
        ),
      );

      final Finder retryButton = find.widgetWithText(HivorrButton, 'Retry');
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(retries, 1);
    });
  });

  group('ConversionRateCard placeholder', () {
    testWidgets('shows guidance while no rate is loaded',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: null,
          fromCurrency: null,
          toCurrency: null,
          isLoading: false,
          isUnavailable: false,
        ),
      );

      expect(
        find.text('Select a pair and an amount to see today\u2019s rate.'),
        findsOneWidget,
      );
    });

    testWidgets('a non-positive rate still shows the placeholder (guarded)',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        const ConversionRateCard(
          rate: 0,
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          isLoading: false,
          isUnavailable: false,
        ),
      );

      expect(
        find.text('Select a pair and an amount to see today\u2019s rate.'),
        findsOneWidget,
      );
    });
  });
}