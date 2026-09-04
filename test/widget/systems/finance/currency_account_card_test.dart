import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/widgets/currency_account_card.dart';

import '../../../support/fakes/finance/fake_financial_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('CurrencyAccountCard', () {
    testWidgets('renders currency code and name for the account',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(currencyCode: 'NGN'),
        ),
      );
      expect(find.textContaining('NGN'), findsOneWidget);
      expect(find.textContaining('Nigerian Naira'), findsOneWidget);
    });

    testWidgets('renders active badge', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(accountStatus: 'active'),
        ),
      );
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders bank name when activated', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(
            receivingBankName: 'Zenith Bank',
            receivingAccountNumber: '0012345678',
          ),
        ),
      );
      expect(find.text('Zenith Bank'), findsOneWidget);
      expect(
        find.text('Account ending 0012345678'),
        findsOneWidget,
      );
    });

    testWidgets('renders pending badge and generic guidance',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(
            currencyCode: 'USD',
            accountStatus: 'pending',
          ),
        ),
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(
        find.textContaining('Connect your USD bank account'),
        findsOneWidget,
      );
    });

    testWidgets('renders pending badge with explicit guidance message',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(
            currencyCode: 'USD',
            accountStatus: 'pending',
          ),
          guidanceMessage: 'Connect USD via Paystack',
        ),
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Connect USD via Paystack'), findsOneWidget);
    });

    testWidgets('renders suspended badge', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(accountStatus: 'suspended'),
        ),
      );
      expect(find.text('Suspended'), findsOneWidget);
    });

    testWidgets('renders closed badge for unknown status',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(accountStatus: 'closed'),
        ),
      );
      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('does not render bank name or account number when absent',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        CurrencyAccountCard(
          account: seedAccountEntity(accountStatus: 'active'),
        ),
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.textContaining('Account ending'), findsNothing);
    });
  });
}
