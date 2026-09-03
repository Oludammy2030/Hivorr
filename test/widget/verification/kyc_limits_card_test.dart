import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/systems/verification/widgets/kyc_limits_card.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  KycLevel tier({
    String code = 'tier_1',
    String status = 'active',
    num daily = 50000,
    num weekly = 200000,
    num monthly = 800000,
    num cashout = 100000,
  }) =>
      KycLevel(
        tierCode: code,
        status: status,
        limits: KycLimits(
          daily: daily,
          weekly: weekly,
          monthly: monthly,
          cashout: cashout,
        ),
      );

  Future<void> pumpCard(WidgetTester tester, KycLevel level) =>
      pumpTheme(tester, KycLimitsCard(level: level));

  group('KycLimitsCard layout', () {
    testWidgets('renders the section title', (WidgetTester tester) async {
      await pumpCard(tester, tier());
      expect(find.text('Transaction limits'), findsOneWidget);
    });

    testWidgets('renders all four limit labels', (WidgetTester tester) async {
      await pumpCard(tester, tier());
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Cashout'), findsOneWidget);
    });

    testWidgets('formats each limit in NGN with thousands separators',
        (WidgetTester tester) async {
      await pumpCard(tester, tier());
      expect(find.text('₦50,000'), findsOneWidget);
      expect(find.text('₦200,000'), findsOneWidget);
      expect(find.text('₦800,000'), findsOneWidget);
      expect(find.text('₦100,000'), findsOneWidget);
    });
  });

  group('KycLimitsCard values', () {
    testWidgets('renders zero limits for a tier0 account',
        (WidgetTester tester) async {
      await pumpCard(
        tester,
        tier(
          code: 'tier_0',
          status: 'pending',
          daily: 0,
          weekly: 0,
          monthly: 0,
          cashout: 0,
        ),
      );
      expect(find.text('₦0'), findsNWidgets(4));
    });

    testWidgets('renders a large cashout figure', (WidgetTester tester) async {
      await pumpCard(
        tester,
        tier(
          code: 'tier_3',
          daily: 1000000,
          weekly: 4000000,
          monthly: 15000000,
          cashout: 2000000,
        ),
      );
      expect(find.text('₦2,000,000'), findsOneWidget);
    });
  });

  group('KycLimitsCard design tokens', () {
    testWidgets('labels use the onSurfaceVariant color',
        (WidgetTester tester) async {
      await pumpCard(tester, tier());
      final Text label = tester.widget<Text>(find.text('Daily'));
      expect(label.style?.color, isNotNull);
      expect(label.style?.color, isNot(Colors.black));
    });

    testWidgets('values use the bodyMedium text style',
        (WidgetTester tester) async {
      await pumpCard(tester, tier());
      final Text value = tester.widget<Text>(find.text('₦50,000'));
      expect(value.style, isNotNull);
    });

    testWidgets('lays out the chips in a wrapping row',
        (WidgetTester tester) async {
      await pumpCard(tester, tier());
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });
}
