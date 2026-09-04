import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/widgets/financial_profile_card.dart';

import '../../../support/fakes/finance/fake_financial_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('FinancialProfileCard', () {
    testWidgets('renders active status chip and default currency',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        FinancialProfileCard(
          profile: seedProfileEntity(status: 'active', defaultCurrency: 'NGN'),
        ),
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.textContaining('Nigerian Naira'), findsOneWidget);
      expect(find.textContaining('Default:'), findsOneWidget);
    });

    testWidgets('renders suspended status', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        FinancialProfileCard(
          profile: seedProfileEntity(status: 'suspended'),
        ),
      );
      expect(find.text('Suspended'), findsOneWidget);
    });

    testWidgets('renders closed status', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        FinancialProfileCard(
          profile: seedProfileEntity(status: 'closed'),
        ),
      );
      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('renders the profile title', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        FinancialProfileCard(
          profile: seedProfileEntity(defaultCurrency: 'USD'),
        ),
      );
      expect(find.text('Financial Profile'), findsOneWidget);
      expect(find.textContaining('US Dollar'), findsOneWidget);
    });
  });
}
