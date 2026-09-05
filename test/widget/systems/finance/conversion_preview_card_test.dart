import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/finance/widgets/conversion_preview_card.dart';

import '../../../support/harnesses/widget_harness.dart';

/// Widget coverage for [ConversionPreviewCard] (EP-02-15 TT-11 ≥8): the zero-
/// RPC estimate lines (give → fee → net) rendered locale-aware via
/// `BalanceFormatter`, the net emphasized with the theme `primary` token,
/// the estimate microcopy, the optional fee line, and the "Convert now" CTA
/// with its executing state.
void main() {
  const ConversionPreview estimate = ConversionPreview(
    fromCurrency: 'NGN',
    toCurrency: 'USD',
    fromAmount: 50000,
    grossAmount: 35,
    fee: 0,
    toAmount: 35,
    exchangeRate: 0.0007,
  );

  const ConversionPreview feeEstimate = ConversionPreview(
    fromCurrency: 'NGN',
    toCurrency: 'USD',
    fromAmount: 50000,
    grossAmount: 45,
    fee: 10,
    toAmount: 35,
    exchangeRate: 0.0009,
  );

  Future<void> pumpCard(
    WidgetTester tester,
    ConversionPreviewCard card,
  ) async {
    await pumpTheme(tester, card);
  }

  group('ConversionPreviewCard estimate lines', () {
    testWidgets('renders the You give label and locale-aware amount',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: null,
          isExecuting: false,
        ),
      );

      expect(find.text('You give'), findsOneWidget);
      expect(find.text('\u20A650,000.00'), findsOneWidget);
    });

    testWidgets('renders the You receive net amount',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: null,
          isExecuting: false,
        ),
      );

      expect(find.text('You receive'), findsOneWidget);
      expect(find.text('\$35.00'), findsOneWidget);
    });

    testWidgets('emphasizes the net with titleMedium in the theme primary color',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: null,
          isExecuting: false,
        ),
      );
      final BuildContext context = tester.element(find.byType(ConversionPreviewCard));

      final Text netText = tester.widget<Text>(find.text('\$35.00'));
      expect(netText.style?.fontSize, Theme.of(context).textTheme.titleMedium?.fontSize);
      expect(netText.style?.color, Theme.of(context).colorScheme.primary);
    });

    testWidgets('renders the estimate microcopy', (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: null,
          isExecuting: false,
        ),
      );

      expect(
        find.text(
          'This is an estimate \u2014 the final amount is confirmed on execution.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ConversionPreviewCard fee handling', () {
    testWidgets('hides the fee line when the fee is zero',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: null,
          isExecuting: false,
        ),
      );

      expect(find.text('Fee'), findsNothing);
    });

    testWidgets('renders the fee line when the fee is positive',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: feeEstimate,
          onExecute: null,
          isExecuting: false,
        ),
      );

      expect(find.text('Fee'), findsOneWidget);
      expect(find.text('\$10.00'), findsOneWidget);
    });
  });

  group('ConversionPreviewCard CTA', () {
    testWidgets('renders the Convert now button and invokes onExecute',
        (WidgetTester tester) async {
      int taps = 0;
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: () => taps++,
          isExecuting: false,
        ),
      );

      expect(find.text('Convert now'), findsOneWidget);
      await tester.tap(find.text('Convert now'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('shows the loader while executing and disables the CTA',
        (WidgetTester tester) async {
      int taps = 0;
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: () => taps++,
          isExecuting: true,
        ),
      );

      expect(find.byType(HivorrLoader), findsOneWidget);
      expect(find.text('Convert now'), findsNothing);
      await tester.tap(find.byType(HivorrLoader), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('renders a disabled CTA when onExecute is null',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        ConversionPreviewCard(
          preview: estimate,
          onExecute: null,
          isExecuting: false,
        ),
      );

      final HivorrButton button =
          tester.widget<HivorrButton>(find.byType(HivorrButton));
      expect(button.onPressed, isNull);
    });
  });
}