import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/widgets/payout_account_limit_display.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('PayoutAccountLimitDisplay', () {
    testWidgets('renders the "Cashout limit" label with a speed icon',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 500000, currencyCode: 'NGN'),
      );
      expect(find.text('Cashout limit'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PayoutAccountLimitDisplay),
          matching: find.byIcon(Icons.speed),
        ),
        findsOneWidget,
      );
    });

    testWidgets('formats the NGN limit with symbol and separators',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 500000, currencyCode: 'NGN'),
      );
      expect(find.text('\u20A6500,000.00'), findsOneWidget);
    });

    testWidgets('formats USD limits with the dollar symbol',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 1500, currencyCode: 'USD'),
      );
      expect(find.text('\$1,500.00'), findsOneWidget);
    });

    testWidgets('formats GHS and GBP limits with their symbols',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 2000, currencyCode: 'GHS'),
      );
      expect(find.text('\u20B52,000.00'), findsOneWidget);

      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 750, currencyCode: 'GBP'),
      );
      expect(find.text('\u00A3750.00'), findsOneWidget);
    });

    testWidgets('formats fractional limits with two decimals',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 1234.5, currencyCode: 'USD'),
      );
      expect(find.text('\$1,234.50'), findsOneWidget);
    });

    testWidgets('uses theme tokens (renders on dark theme too)',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountLimitDisplay(limit: 500000, currencyCode: 'NGN'),
        dark: true,
      );
      expect(find.text('\u20A6500,000.00'), findsOneWidget);
    });
  });
}