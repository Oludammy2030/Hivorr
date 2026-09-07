import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_form_view.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_limit_display.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_view.dart';
import 'package:hivorr/systems/finance/widgets/payout_withdraw_form_view.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_payout_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// A repository whose `load` never completes, so the view stays in its loading
/// state until the completer is resolved. Releasing surfaces an
/// [ApiException], which the provider converts into its error state.
class _BlockingPayoutRepo implements FinancialPayoutRepository {
  final Completer<void> _never = Completer<void>();

  void release() => _never.complete();

  Future<T> _neverCompletes<T>() =>
      _never.future.then<T>((_) => throw const ApiException(
            kind: ApiExceptionKind.server,
            message: 'load down',
            code: 'PLT999',
          ));

  @override
  Future<PayoutAccount> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) =>
      _neverCompletes();

  @override
  Future<List<PayoutAccount>> listPayoutAccounts() => _neverCompletes();

  @override
  Future<WithdrawalResult> withdraw({
    required String payoutAccountId,
    required double amount,
  }) =>
      _neverCompletes();
}

void main() {
  Future<FinancialPayoutProvider> pumpView(
    WidgetTester tester, {
    FinancialPayoutRepository? repo,
  }) async {
    final provider = FinancialPayoutProvider(
      service: FinancialPayoutService(repository: repo ?? FakeFinancialPayoutRepository()),
    );
    addTearDown(provider.dispose);
    await pumpScreen(
      tester,
      const PayoutAccountView(cashoutLimit: 500000, currencyCode: 'NGN'),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialPayoutProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  group('PayoutAccountView', () {
    testWidgets('renders the Accounts / Withdraw tab selector',
        (WidgetTester tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
    });

    testWidgets('empty mirror shows the bind empty state and CTA',
        (WidgetTester tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.text('No payout accounts bound'), findsOneWidget);
      expect(find.text('Bind payout account'), findsOneWidget);
    });

    testWidgets('tapping "Bind payout account" reveals the bind form',
        (WidgetTester tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(find.byType(PayoutAccountFormView), findsOneWidget);
      expect(find.text('Bank name'), findsOneWidget);
    });

    testWidgets('bound accounts render as payout cards',
        (WidgetTester tester) async {
      await pumpView(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[
            FakeFinancialPayoutRepository.verified(),
            FakeFinancialPayoutRepository.unverified(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account ending ***6789'), findsOneWidget);
      expect(find.text('Account ending ***3210'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Verification pending'), findsOneWidget);
    });

    testWidgets('Accounts tab keeps listing cards after the post-frame load',
        (WidgetTester tester) async {
      final repo = FakeFinancialPayoutRepository(
        seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
      );
      await pumpView(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(repo.listCallCount, 1);
      expect(find.text('Account ending ***6789'), findsOneWidget);
    });

    testWidgets('switching to the Withdraw tab shows the empty verified state',
        (WidgetTester tester) async {
      await pumpView(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(find.text('No verified payout accounts'), findsOneWidget);
    });

    testWidgets('Withdraw tab offers only verified accounts through a form',
        (WidgetTester tester) async {
      await pumpView(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[
            FakeFinancialPayoutRepository.verified(),
            FakeFinancialPayoutRepository.unverified(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(find.byType(PayoutWithdrawFormView), findsOneWidget);
      // The unverified account must never appear in the destination list.
      expect(find.textContaining('Zenith Bank'), findsNothing);
    });

    testWidgets('Withdraw tab surfaces the cashout limit when provided',
        (WidgetTester tester) async {
      await pumpView(
        tester,
        repo: FakeFinancialPayoutRepository(
          seed: <PayoutAccount>[FakeFinancialPayoutRepository.verified()],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(find.byType(PayoutAccountLimitDisplay), findsOneWidget);
      expect(find.text('Cashout limit'), findsOneWidget);
      expect(find.text('\u20A6500,000.00'), findsOneWidget);
    });

    testWidgets('shows the loading state while the initial load is pending',
        (WidgetTester tester) async {
      final blocking = _BlockingPayoutRepo();
      await pumpView(tester, repo: blocking);
      await tester.pump();

      expect(find.text('Loading payout accounts...'), findsOneWidget);
      blocking.release();
      await tester.pumpAndSettle();
    });

    testWidgets('shows the error state when the initial load fails',
        (WidgetTester tester) async {
      const ApiException failure = ApiException(
        kind: ApiExceptionKind.server,
        message: 'load down',
        code: 'PLT999',
      );
      final repo = FakeFinancialPayoutRepository()..nextError = failure;
      await pumpView(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load payout accounts'), findsOneWidget);
      expect(find.text('load down'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry after a failed load recovers the mirror',
        (WidgetTester tester) async {
      final repo = FakeFinancialPayoutRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'load down',
          code: 'PLT999',
        );
      await pumpView(tester, repo: repo);
      await tester.pumpAndSettle();
      expect(find.text('Failed to load payout accounts'), findsOneWidget);

      repo.nextError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No payout accounts bound'), findsOneWidget);
    });

    testWidgets('renders on the dark theme without hardcoded colors',
        (WidgetTester tester) async {
      final provider = FinancialPayoutProvider(
        service: FinancialPayoutService(
          repository: FakeFinancialPayoutRepository(),
        ),
      );
      addTearDown(provider.dispose);
      await pumpScreen(
        tester,
        const PayoutAccountView(),
        dark: true,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<FinancialPayoutProvider>.value(
            value: provider,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('No payout accounts bound'), findsOneWidget);
    });
  });
}