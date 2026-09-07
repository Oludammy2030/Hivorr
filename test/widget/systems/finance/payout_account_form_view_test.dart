import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_form_view.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_payout_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// A repository whose `bindAccount` is gated by a completer so the in-flight
/// loading state can be asserted.
class _PendingBindRepo implements FinancialPayoutRepository {
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<PayoutAccount> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) =>
      _gate.future.then(
        (_) => PayoutAccount(
          id: 'acc-new',
          currencyCode: currencyCode,
          bankName: bankName,
          accountNumber: accountNumber,
          accountName: accountName,
          status: PayoutAccountStatus.pending,
        ),
      );

  @override
  Future<List<PayoutAccount>> listPayoutAccounts() async => const [];

  @override
  Future<WithdrawalResult> withdraw({
    required String payoutAccountId,
    required double amount,
  }) async =>
      throw StateError('not used');
}

void main() {
  Future<FinancialPayoutProvider> pumpForm(
    WidgetTester tester, {
    FinancialPayoutRepository? repo,
    ValueChanged<PayoutAccount>? onBound,
  }) async {
    final provider = FinancialPayoutProvider(
      service: FinancialPayoutService(
        repository: repo ?? FakeFinancialPayoutRepository(),
      ),
    );
    addTearDown(provider.dispose);
    await pumpScreen(
      tester,
      PayoutAccountFormView(onBound: onBound),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialPayoutProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  Future<void> enterValidForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Guaranty Trust');
    await tester.enterText(find.byType(TextField).at(1), '0123456789');
    await tester.enterText(find.byType(TextField).at(2), 'John Doe');
  }

  group('PayoutAccountFormView', () {
    testWidgets('renders currency dropdown with the four supported currencies',
        (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();

      expect(find.text('Currency'), findsOneWidget);
      expect(find.textContaining('Nigerian Naira'), findsOneWidget);

      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ghanaian Cedi'), findsOneWidget);
      expect(find.textContaining('US Dollar'), findsOneWidget);
      expect(find.textContaining('British Pound'), findsOneWidget);
    });

    testWidgets('renders the three inputs and the bind button',
        (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();

      expect(find.text('Bank name'), findsOneWidget);
      expect(find.text('Account number'), findsOneWidget);
      expect(find.text('Account name'), findsOneWidget);
      expect(find.text('Bind payout account'), findsOneWidget);
    });

    testWidgets('empty submit surfaces the required-field + NUBAN errors',
        (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Bind payout account'));
      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the bank name'), findsOneWidget);
      expect(find.text('Enter the account name'), findsOneWidget);
      expect(find.text('Enter the account number'), findsOneWidget);
    });

    testWidgets('a 9-digit NUBAN is rejected', (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '012345678');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Bind payout account'));
      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(find.text('NGN account numbers are 10 digits (NUBAN)'), findsOneWidget);
    });

    testWidgets('non-numeric account numbers are rejected',
        (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'abcdefghij');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Bind payout account'));
      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Account number must contain digits only'),
        findsOneWidget,
      );
    });

    testWidgets('non-NGN currencies accept 8-15 digit account numbers',
        (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Nigerian Naira'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('US Dollar').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Bank of America');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.enterText(find.byType(TextField).at(2), 'Jane Doe');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Bind payout account'));
      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Account number must be between 8 and 15 digits'),
        findsNothing,
      );
    });

    testWidgets('a successful bind invokes onBound and clears the form',
        (WidgetTester tester) async {
      PayoutAccount? bound;
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository(),
        onBound: (PayoutAccount a) => bound = a,
      );

      await enterValidForm(tester);
      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(bound, isNotNull);
      expect(bound!.accountNumber, '0123456789');
      // The form resets after a successful bind.
      expect(find.text('Bank name'), findsOneWidget);
    });

    testWidgets('a bind failure surfaces the typed message inline',
        (WidgetTester tester) async {
      const ApiException conflict = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Account number already bound.',
        code: 'PLT005',
      );
      await pumpForm(
        tester,
        repo: FakeFinancialPayoutRepository()..nextError = conflict,
      );

      await enterValidForm(tester);
      await tester.tap(find.text('Bind payout account'));
      await tester.pumpAndSettle();

      expect(find.text('Account number already bound.'), findsOneWidget);
    });

    testWidgets('shows the branded loader while a bind is in flight',
        (WidgetTester tester) async {
      final blocking = _PendingBindRepo();
      await pumpForm(tester, repo: blocking);

      await enterValidForm(tester);
      await tester.tap(find.text('Bind payout account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HivorrLoader), findsOneWidget);
      expect(find.text('Bind payout account'), findsNothing);

      blocking.release();
      await tester.pumpAndSettle();
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
        const PayoutAccountFormView(),
        dark: true,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<FinancialPayoutProvider>.value(
            value: provider,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('Bind payout account'), findsOneWidget);
    });
  });
}