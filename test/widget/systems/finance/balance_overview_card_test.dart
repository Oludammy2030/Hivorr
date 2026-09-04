import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/systems/finance/widgets/balance_chip.dart';
import 'package:hivorr/systems/finance/widgets/balance_overview_card.dart';

import '../../../support/fakes/finance/fake_financial_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('BalanceChip', () {
    testWidgets('renders available balance with formatted amount',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const BalanceChip(
          currencyCode: 'NGN',
          amount: 50000,
          kind: BalanceChipKind.available,
        ),
      );
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('\u20A650,000.00'), findsOneWidget);
    });

    testWidgets('uses successContainer for available', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const BalanceChip(
          currencyCode: 'USD',
          amount: 100,
          kind: BalanceChipKind.available,
        ),
      );
      final Container container = tester.widget(
        find.descendant(
          of: find.byType(BalanceChip),
          matching: find.byType(Container),
        ),
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        AppTheme.lightTheme.extension<AppThemeExtension>()!.successContainer,
      );
    });

    testWidgets('uses primaryContainer for held', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const BalanceChip(
          currencyCode: 'NGN',
          amount: 0,
          kind: BalanceChipKind.held,
        ),
      );
      expect(find.text('Held'), findsOneWidget);
      expect(find.text('\u20A60.00'), findsOneWidget);
    });

    testWidgets('uses warningContainer for pending', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const BalanceChip(
          currencyCode: 'GBP',
          amount: 12.5,
          kind: BalanceChipKind.pending,
        ),
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('\u00A312.50'), findsOneWidget);
    });

    testWidgets('has semantics label', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const BalanceChip(
          currencyCode: 'NGN',
          amount: 0,
          kind: BalanceChipKind.available,
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Available balance .*')),
        findsOneWidget,
      );
    });
  });

  group('BalanceOverviewCard', () {
    testWidgets('renders a Balances title and per-currency label',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        BalanceOverviewCard(
          balances: <String, Balance>{
            'NGN': seedBalanceEntity(currencyCode: 'NGN', available: 100),
          },
        ),
      );
      expect(find.text('Balances'), findsOneWidget);
      expect(find.textContaining('Nigerian Naira'), findsOneWidget);
      expect(find.textContaining('(NGN)'), findsOneWidget);
    });

    testWidgets('renders available, held, and pending chips for a currency',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        BalanceOverviewCard(
          balances: <String, Balance>{
            'USD': seedBalanceEntity(
              currencyCode: 'USD',
              available: 100,
              held: 20,
              pending: 5,
            ),
          },
        ),
      );
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Held'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('\$100.00'), findsOneWidget);
      expect(find.text('\$20.00'), findsOneWidget);
      expect(find.text('\$5.00'), findsOneWidget);
    });

    testWidgets('renders nothing when there are no balances',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const BalanceOverviewCard(balances: <String, Balance>{}),
      );
      expect(find.text('Balances'), findsNothing);
    });

    testWidgets('sort default currency first then alphabetical',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        BalanceOverviewCard(
          balances: <String, Balance>{
            'NGN': seedBalanceEntity(currencyCode: 'NGN'),
            'USD': seedBalanceEntity(currencyCode: 'USD'),
            'GBP': seedBalanceEntity(currencyCode: 'GBP'),
          },
          defaultCurrencyCode: 'NGN',
        ),
      );
      final List<String> labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data ?? '')
          .where((String s) => s.contains('('))
          .toList();
      expect(labels.first, contains('NGN'));
      expect(labels.any((String s) => s.contains('GBP')), isTrue);
      expect(labels.any((String s) => s.contains('USD')), isTrue);
    });
  });
}
