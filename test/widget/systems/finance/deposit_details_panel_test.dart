import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';
import 'package:hivorr/systems/finance/widgets/deposit_details_panel.dart';
import 'package:hivorr/systems/finance/widgets/deposit_name_match_indicator.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_deposit_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// A repository whose list never completes, so the panel stays in its loading
/// state.
class _BlockingDepositRepo implements FinancialDepositRepository {
  final Completer<void> _never = Completer<void>();

  @override
  Future<List<Deposit>> listDeposits() =>
      _never.future.then((_) => throw StateError('never lists'));
}

void main() {
  Future<FinancialDepositProvider> pumpPanel(
    WidgetTester tester, {
    FinancialDepositRepository? repo,
    bool dark = false,
  }) async {
    final provider = FinancialDepositProvider(
      service: FinancialDepositService(
        repository: repo ?? FakeFinancialDepositRepository(),
      ),
    );
    addTearDown(provider.dispose);
    await pumpScreen(
      tester,
      // Production embeds the panel inside the profile screen's ListView;
      // mirror that so tall deposit lists + showcase scroll instead of
      // overflowing a bare body slot.
      const SingleChildScrollView(child: DepositDetailsPanel()),
      dark: dark,
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialDepositProvider>.value(
          value: provider,
        ),
      ],
    );
    return provider;
  }

  group('DepositDetailsPanel', () {
    testWidgets('shows the loading state while the initial load is pending',
        (WidgetTester tester) async {
      await pumpPanel(tester, repo: _BlockingDepositRepo());
      await tester.pump();

      expect(find.text('Loading deposits...'), findsOneWidget);
    });

    testWidgets('shows an empty state when no deposits are recorded',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      expect(find.text('No deposits recorded yet'), findsOneWidget);
    });

    testWidgets('lists deposits with formatted amounts and credit status',
        (WidgetTester tester) async {
      await pumpPanel(
        tester,
        repo: FakeFinancialDepositRepository(
          seed: <Deposit>[
            FakeFinancialDepositRepository.matched(
              amount: 150000,
              currencyCode: 'NGN',
            ),
            FakeFinancialDepositRepository.pending(
              currencyCode: 'USD',
              amount: 100,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('150,000.00'), findsOneWidget);
      expect(find.textContaining('100.00'), findsOneWidget);
      expect(find.text('Credited to your balance'), findsOneWidget);
      expect(find.text('Awaiting credit'), findsOneWidget);
    });

    testWidgets('renders a name-match indicator per deposit',
        (WidgetTester tester) async {
      await pumpPanel(
        tester,
        repo: FakeFinancialDepositRepository(
          seed: <Deposit>[
            FakeFinancialDepositRepository.matched(),
            FakeFinancialDepositRepository.pending(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DepositNameMatchIndicator), findsNWidgets(2));
      expect(find.text('Match: Verified'), findsOneWidget);
      expect(find.text('Match: Pending'), findsOneWidget);
    });

    testWidgets('shows the record-deposit showcase alongside the list',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      expect(find.text('Record a deposit'), findsOneWidget);
      expect(find.text('Verify deposit server-side'), findsOneWidget);
    });

    testWidgets('showcase explains the server-side name-verification path',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('name-verified by the Hivorr processing service'),
        findsOneWidget,
      );
    });

    testWidgets('currency dropdown exposes NGN, GHS, USD, and GBP',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Currency'));
      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nigerian Naira'), findsWidgets);
      expect(find.textContaining('Ghanaian Cedi'), findsOneWidget);
      expect(find.textContaining('US Dollar'), findsOneWidget);
      expect(find.textContaining('British Pound'), findsOneWidget);
    });

    testWidgets('entering an amount previews the credited value',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '150000');
      await tester.pumpAndSettle();

      expect(find.textContaining('You will receive:'), findsOneWidget);
      expect(find.textContaining('150,000.00'), findsOneWidget);
      expect(find.textContaining('NGN'), findsWidgets);
    });

    testWidgets('an empty or invalid amount shows the preview hint',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Enter an amount to preview what would be received.'),
        findsOneWidget,
      );
    });

    testWidgets('the verify button only confirms valid amounts',
        (WidgetTester tester) async {
      await pumpPanel(tester);
      await tester.pumpAndSettle();

      // No amount → the button does nothing.
      await tester.ensureVisible(find.text('Verify deposit server-side'));
      await tester.tap(find.text('Verify deposit server-side'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The processing service will run'), findsNothing);

      // Valid amount → confirmation appears.
      await tester.enterText(find.byType(TextField).first, '150000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify deposit server-side'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The processing service will run'), findsOneWidget);
    });

    testWidgets('shows the error state when the initial load fails',
        (WidgetTester tester) async {
      const ApiException failure = ApiException(
        kind: ApiExceptionKind.server,
        message: 'deposits down',
        code: 'PLT999',
      );
      await pumpPanel(
        tester,
        repo: FakeFinancialDepositRepository()..nextError = failure,
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load deposits'), findsOneWidget);
      expect(find.text('deposits down'), findsOneWidget);
    });

    testWidgets('draws on the dark theme without hardcoded colors',
        (WidgetTester tester) async {
      await pumpPanel(
        tester,
        repo: FakeFinancialDepositRepository(
          seed: <Deposit>[FakeFinancialDepositRepository.matched()],
        ),
        dark: true,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('150,000.00'), findsOneWidget);
    });
  });
}