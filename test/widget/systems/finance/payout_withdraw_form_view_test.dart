import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_limit_display.dart';
import 'package:hivorr/systems/finance/widgets/payout_withdraw_form_view.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_payout_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  Future<FinancialPayoutProvider> pumpForm(
    WidgetTester tester, {
    FakeFinancialPayoutRepository? repo,
    double? cashoutLimit,
    ValueChanged<WithdrawalResult>? onWithdrawSuccess,
  }) async {
    final provider = FinancialPayoutProvider(
      service: FinancialPayoutService(
        repository: repo ?? FakeFinancialPayoutRepository(),
      ),
    );
    addTearDown(provider.dispose);
    await provider.load();
    await pumpScreen(
      tester,
      PayoutWithdrawFormView(
        cashoutLimit: cashoutLimit,
        currencyCode: 'NGN',
        onWithdrawSuccess: onWithdrawSuccess,
      ),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialPayoutProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  group('PayoutWithdrawFormView', () {
    testWidgets('shows an empty state when no verified accounts exist',
        (WidgetTester tester) async {
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.unverified()],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No verified payout accounts'), findsOneWidget);
      expect(find.text('Withdraw'), findsNothing);
    });

    testWidgets('offers verified accounts in the destination dropdown',
        (WidgetTester tester) async {
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[
            FakeFinancialPayoutRepository.verified(
              id: 'acc-verified',
              currencyCode: 'NGN',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payout account'), findsOneWidget);
      expect(find.textContaining('Acc ending ***6789'), findsNothing);
      expect(find.text('Withdraw'), findsWidgets);
    });

    testWidgets('validates that the amount is greater than zero',
        (WidgetTester tester) async {
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').first);
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    });

    testWidgets('rejects amounts above the cashout limit',
        (WidgetTester tester) async {
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
        ),
        cashoutLimit: 500000,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '600000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Withdrawals are capped by your cashout limit'),
        findsOneWidget,
      );
    });

    testWidgets('shows the cashout limit display when a limit is provided',
        (WidgetTester tester) async {
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
        ),
        cashoutLimit: 500000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(PayoutAccountLimitDisplay), findsOneWidget);
      expect(find.text('\u20A6500,000.00'), findsOneWidget);
    });

    testWidgets('a successful withdrawal invokes onWithdrawSuccess',
        (WidgetTester tester) async {
      WithdrawalResult? received;
      final repo = FakeFinancialPayoutRepository(
        seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
        nextWithdrawalResult: const WithdrawalResult(
          payoutId: 'pay-9',
          amount: 50000,
          fee: 0,
          netAmount: 50000,
          cashoutRemaining: 450000,
        ),
      );
      await pumpForm(
        tester,
        repo: repo,
        onWithdrawSuccess: (WithdrawalResult r) => received = r,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '50000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').first);
      await tester.pumpAndSettle();

      expect(repo.withdrawCallCount, 1);
      expect(repo.lastWithdrawalAccountId, 'acc-verified');
      expect(received, isNotNull);
      expect(received!.payoutId, 'pay-9');
      expect(received!.cashoutRemaining, 450000);
    });

    testWidgets('surfaces a typed failure message inline',
        (WidgetTester tester) async {
      const ApiException insufficient = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Insufficient balance.',
        code: 'PLT006',
      );
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
          nextWithdrawError: insufficient,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '50000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').first);
      await tester.pumpAndSettle();

      expect(find.text('Insufficient balance.'), findsOneWidget);
    });
  });
}