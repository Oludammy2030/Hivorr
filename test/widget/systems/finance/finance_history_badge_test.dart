import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/finance/widgets/finance_history_badge.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_deposit_repository.dart';
import '../../../support/fakes/finance/fake_financial_payout_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  Future<void> pumpBadge(
    WidgetTester tester, {
    FakeFinancialPayoutRepository? payoutRepo,
    FakeFinancialDepositRepository? depositRepo,
    bool dark = false,
  }) async {
    final payoutProvider = FinancialPayoutProvider(
      service: FinancialPayoutService(
        repository: payoutRepo ?? FakeFinancialPayoutRepository(),
      ),
    );
    final depositProvider = FinancialDepositProvider(
      service: FinancialDepositService(
        repository: depositRepo ?? FakeFinancialDepositRepository(),
      ),
    );
    addTearDown(payoutProvider.dispose);
    addTearDown(depositProvider.dispose);
    await payoutProvider.load();
    await depositProvider.load();
    await pumpApp(
      tester,
      const FinanceHistoryBadge(),
      dark: dark,
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialPayoutProvider>.value(
          value: payoutProvider,
        ),
        ChangeNotifierProvider<FinancialDepositProvider>.value(
          value: depositProvider,
        ),
      ],
    );
  }

  group('FinanceHistoryBadge', () {
    testWidgets('shows zero counts for an empty financial history',
        (WidgetTester tester) async {
      await pumpBadge(tester);

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('0 payout accounts'), findsOneWidget);
      expect(find.text('0 deposits'), findsOneWidget);
    });

    testWidgets('shows the bound payout-account count',
        (WidgetTester tester) async {
      await pumpBadge(
        tester,
        payoutRepo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[
            FakeFinancialPayoutRepository.verified(),
            FakeFinancialPayoutRepository.unverified(),
          ],
        ),
      );

      expect(find.text('2 payout accounts'), findsOneWidget);
      expect(find.text('0 deposits'), findsOneWidget);
    });

    testWidgets('shows the recorded-deposit count',
        (WidgetTester tester) async {
      await pumpBadge(
        tester,
        depositRepo: FakeFinancialDepositRepository(
          seed: <Deposit>[
            FakeFinancialDepositRepository.matched(),
            FakeFinancialDepositRepository.matched(),
            FakeFinancialDepositRepository.pending(),
          ],
        ),
      );

      expect(find.text('0 payout accounts'), findsOneWidget);
      expect(find.text('3 deposits'), findsOneWidget);
    });

    testWidgets('shows both counts together', (WidgetTester tester) async {
      await pumpBadge(
        tester,
        payoutRepo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
        ),
        depositRepo: FakeFinancialDepositRepository(
          seed: <Deposit>[FakeFinancialDepositRepository.matched()],
        ),
      );

      expect(find.text('1 payout accounts'), findsOneWidget);
      expect(find.text('1 deposits'), findsOneWidget);
    });

    testWidgets('draws on the dark theme', (WidgetTester tester) async {
      await pumpBadge(tester, dark: true);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('0 payout accounts'), findsOneWidget);
    });
  });
}