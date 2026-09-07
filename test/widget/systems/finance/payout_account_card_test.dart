import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_card.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  const PayoutAccount ngn = PayoutAccount(
    id: 'acc-1',
    currencyCode: 'NGN',
    bankName: 'Guaranty Trust',
    accountNumber: '0123456789',
    accountName: 'John Doe',
    status: PayoutAccountStatus.pending,
  );

  group('PayoutAccountCard', () {
    testWidgets('shows currency, bank, and masked account number',
        (WidgetTester tester) async {
      await pumpTheme(tester, const PayoutAccountCard(account: ngn));
      expect(find.textContaining('NGN'), findsOneWidget);
      expect(find.text('Guaranty Trust'), findsOneWidget);
      expect(find.text('Account ending ***6789'), findsOneWidget);
    });

    testWidgets('never shows the raw account number', (WidgetTester tester) async {
      await pumpTheme(tester, const PayoutAccountCard(account: ngn));
      expect(find.textContaining('0123456789'), findsNothing);
    });

    testWidgets('unverified → "Verification pending" badge on warningContainer',
        (WidgetTester tester) async {
      await pumpTheme(tester, const PayoutAccountCard(account: ngn));
      expect(find.text('Verification pending'), findsOneWidget);
    });

    testWidgets('verified active → "Verified" badge and usable icon',
        (WidgetTester tester) async {
      const PayoutAccount verified = PayoutAccount(
        id: 'acc-2',
        currencyCode: 'NGN',
        bankName: 'GT Bank',
        accountNumber: '9876543210',
        accountName: 'John Doe',
        status: PayoutAccountStatus.active,
        isVerified: true,
        isDefault: true,
      );
      await pumpTheme(tester, const PayoutAccountCard(account: verified));
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Verification pending'), findsNothing);
      expect(find.text('Account ending ***3210'), findsOneWidget);
    });

    testWidgets('deactivated → "Deactivated" badge',
        (WidgetTester tester) async {
      const PayoutAccount deactivated = PayoutAccount(
        id: 'acc-3',
        currencyCode: 'USD',
        bankName: 'Bank',
        accountNumber: '123456789012',
        accountName: 'Jane',
        status: PayoutAccountStatus.deactivated,
        isVerified: true,
      );
      await pumpTheme(tester, const PayoutAccountCard(account: deactivated));
      expect(find.text('Deactivated'), findsOneWidget);
    });

    testWidgets('unknown currency codes render verbatim',
        (WidgetTester tester) async {
      const PayoutAccount exotic = PayoutAccount(
        id: 'acc-4',
        currencyCode: 'KES',
        bankName: 'Bank',
        accountNumber: '12345678',
        accountName: 'Jane',
        status: PayoutAccountStatus.pending,
      );
      await pumpTheme(tester, const PayoutAccountCard(account: exotic));
      expect(find.text('KES'), findsOneWidget);
    });

    testWidgets('draws on the dark theme without hardcoded colors',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const PayoutAccountCard(account: ngn),
        dark: true,
      );
      expect(find.text('Verification pending'), findsOneWidget);
    });
  });
}