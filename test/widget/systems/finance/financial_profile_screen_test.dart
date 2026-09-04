import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/account_activation_guidance.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';
import 'package:hivorr/systems/finance/screens/financial_profile_screen.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';
import 'package:hivorr/systems/finance/widgets/balance_overview_card.dart';
import 'package:hivorr/systems/finance/widgets/financial_profile_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_financial_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

/// A repository whose profile fetch never completes, so the screen stays in its
/// loading state (the provider's `load` hangs on `getProfile`).
class _BlockingRepo implements FinancialRepository {
  _BlockingRepo();
  final Completer<void> _never = Completer<void>();

  @override
  Future<FinancialProfile?> getProfile() =>
      _never.future.then((_) => throw StateError('never'));

  @override
  Future<List<CurrencyAccount>> getAccounts() =>
      _never.future.then((_) => throw StateError('never'));

  @override
  Future<Balance?> getBalance(String currencyCode) =>
      _never.future.then((_) => throw StateError('never'));

  @override
  Future<FinancialStatus> getStatus() =>
      _never.future.then((_) => throw StateError('never'));

  @override
  Future<FinancialProfile> createProfile({String defaultCurrency = 'NGN'}) =>
      _never.future.then((_) => throw StateError('never'));

  @override
  Future<AccountActivationGuidance> requestAccountActivation({
    required String currencyCode,
  }) =>
      _never.future.then((_) => throw StateError('never'));
}

void main() {
  Future<FinancialProvider> pumpScreenWith(
    WidgetTester tester, {
    FinancialRepository? repo,
  }) async {
    final r = repo ?? FakeFinancialRepository();
    final FinancialProvider provider =
        FinancialProvider(service: FinancialService(repository: r));
    await pumpApp(
      tester,
      const FinancialProfileScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<FinancialProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  group('FinancialProfileScreen', () {
    testWidgets('renders app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();
      expect(find.text('Financial Profile'), findsOneWidget);
      // Await the post-frame load to settle async.
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when no profile exists',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository()..setProfile(null);
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('No financial profile yet'), findsOneWidget);
      expect(find.text('Set up your financial profile'), findsOneWidget);
    });

    testWidgets('shows loading state while profile fetch is in flight',
        (WidgetTester tester) async {
      await pumpScreenWith(tester, repo: _BlockingRepo());
      await tester.pump();
      expect(find.text('Loading financial profile...'), findsOneWidget);
      // Unmount to drop the pending never-completing future.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('renders profile card when profile exists',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'active'),
        status: seedStatusEntity(
          balances: <Balance>[seedBalanceEntity(currencyCode: 'NGN')],
        ),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Balances'), findsOneWidget);
      expect(find.text('\u20A650,000.00'), findsOneWidget);
      expect(find.text('\u20A60.00'), findsNWidgets(2)); // held + pending
    });

    testWidgets('shows error state on load failure', (WidgetTester tester) async {
      final repo2 = FakeFinancialRepository()
        ..setProfile(seedProfileEntity())
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'X9',
        );
      await pumpScreenWith(tester, repo: repo2);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load financial profile'), findsOneWidget);
    });

    testWidgets('renders profile and balance cards when loaded',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'active'),
        status: seedStatusEntity(
          balances: <Balance>[seedBalanceEntity(currencyCode: 'NGN')],
        ),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.byType(FinancialProfileCard), findsOneWidget);
      expect(find.byType(BalanceOverviewCard), findsOneWidget);
    });

    testWidgets('shows suspended terminal state with contact support',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'suspended'),
        status: seedStatusEntity(
          profileStatus: 'suspended',
          balances: <Balance>[seedBalanceEntity(currencyCode: 'NGN')],
        ),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(
        find.text('Your financial profile is suspended'),
        findsOneWidget,
      );
      expect(find.text('Contact support to resolve this.'), findsOneWidget);
    });

    testWidgets('shows closed terminal state with contact support',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'closed'),
        status: seedStatusEntity(
          profileStatus: 'closed',
          balances: <Balance>[seedBalanceEntity(currencyCode: 'NGN')],
        ),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Your financial profile is closed'), findsOneWidget);
      expect(find.text('Contact support to resolve this.'), findsOneWidget);
    });

    testWidgets('shows Manage action when a profile exists',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'active'),
        status: seedStatusEntity(),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Manage'), findsOneWidget);
    });

    testWidgets('hides Manage action when no profile exists',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository()..setProfile(null);
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Manage'), findsNothing);
    });

    testWidgets('hides create CTA when a profile exists',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'active'),
        status: seedStatusEntity(),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();
      expect(find.text('Set up your financial profile'), findsNothing);
    });

    testWidgets('shows receiving accounts placeholder when none configured',
        (WidgetTester tester) async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(status: 'active'),
        status: seedStatusEntity(),
      );
      await pumpScreenWith(tester, repo: repo);
      await tester.pumpAndSettle();
      expect(
        find.text('No receiving accounts configured yet.'),
        findsOneWidget,
      );
    });
  });
}
