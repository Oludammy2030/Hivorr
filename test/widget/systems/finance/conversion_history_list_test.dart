import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/finance/widgets/conversion_history_list.dart';

import '../../../support/fakes/finance/fake_conversion_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// Widget coverage for [ConversionHistoryList] (EP-02-15 TT-12 ≥8): the
/// reverse-chronological tiles with give→receive amounts, applied rate + date,
/// lifecycle status chips (`completed`/`failed`/`pending`), the empty state,
/// and the AppThemeExtension `successContainer` token for completed chips.
void main() {
  List<CurrencyConversion> mixedHistory() => <CurrencyConversion>[
        seedConversionEntity(
          id: 'c-completed',
          status: 'completed',
        ),
        seedConversionEntity(
          id: 'c-failed',
          fromCurrency: 'USD',
          toCurrency: 'GHS',
          fromAmount: 10,
          toAmount: 0,
          status: 'failed',
        ),
        seedConversionEntity(
          id: 'c-pending',
          fromCurrency: 'GHS',
          toCurrency: 'NGN',
          fromAmount: 5,
          toAmount: 5555.55,
          status: 'pending',
        ),
      ];

  group('ConversionHistoryList tiles', () {
    testWidgets('renders give-to-receive amounts from BalanceFormatter',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: <CurrencyConversion>[seedConversionEntity()]),
      );

      expect(find.text('\u20A650,000.00 \u2192 \$35.00'), findsOneWidget);
    });

    testWidgets('renders the applied rate with the tile date',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: <CurrencyConversion>[seedConversionEntity()]),
      );

      expect(
        find.textContaining('1 NGN = 0.0007 USD \u00B7'),
        findsOneWidget,
      );
    });

    testWidgets('renders a Completed chip for a completed conversion',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: mixedHistory()),
      );

      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('renders a Failed chip for a failed conversion',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: mixedHistory()),
      );

      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('renders a Pending chip for a pending conversion',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: mixedHistory()),
      );

      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('lays tiles out in the provided newest-first order',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: mixedHistory()),
      );

      final double completedY =
          tester.getTopLeft(find.text('Completed')).dy;
      final double failedY = tester.getTopLeft(find.text('Failed')).dy;
      final double pendingY = tester.getTopLeft(find.text('Pending')).dy;

      expect(completedY, lessThan(failedY));
      expect(failedY, lessThan(pendingY));
    });
  });

  group('ConversionHistoryList status chip styling', () {
    testWidgets('completed chips use the successContainer theme token',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: mixedHistory()),
      );
      final BuildContext context = tester.element(find.byType(ConversionHistoryList));
      final AppThemeExtension ext = context.appExtension;

      final Finder completedChipContainer = find
          .ancestor(of: find.text('Completed'), matching: find.byType(Container))
          .first;
      final Container container =
          tester.widget<Container>(completedChipContainer);
      expect(
        (container.decoration as BoxDecoration).color,
        ext.successContainer,
      );
    });

    testWidgets('tiles use the shared card surface',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        ConversionHistoryList(history: mixedHistory()),
      );

      expect(find.byType(HivorrCard), findsNWidgets(3));
    });
  });

  group('ConversionHistoryList empty state', () {
    testWidgets('shows the branded empty state when history is empty',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const ConversionHistoryList(history: <CurrencyConversion>[]),
      );

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('No conversions yet'), findsOneWidget);
    });
  });
}