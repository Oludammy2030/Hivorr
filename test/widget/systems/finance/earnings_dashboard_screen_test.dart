import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/systems/finance/screens/earnings_dashboard_screen.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_earnings_repository.dart';
import '../../../support/fakes/finance/fake_financial_deposit_repository.dart';
import '../../../support/fakes/finance/fake_financial_payout_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  Future<EarningsProvider> summaryProvider({
    FakeEarningsRepository? repository,
  }) async {
    final FakeEarningsRepository repo =
        repository ?? FakeEarningsRepository();
    final EarningsProvider provider = EarningsProvider(
      service: ServiceEarningsService(repository: repo),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  Future<TransactionHistoryProvider> historyProvider({
    FakeEarningsRepository? repository,
  }) async {
    final FakeEarningsRepository repo =
        repository ?? FakeEarningsRepository();
    final TransactionHistoryProvider provider = TransactionHistoryProvider(
      service: ServiceEarningsService(repository: repo),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  Future<List<SingleChildWidget>> dashboardProviders({
    FakeEarningsRepository? repository,
  }) async {
    final FakeEarningsRepository repo =
        repository ?? FakeEarningsRepository();
    final EarningsProvider summary = await summaryProvider(repository: repo);
    final TransactionHistoryProvider history = await historyProvider(
      repository: repo,
    );
    await summary.load();
    await history.load();
    final FinancialPayoutProvider payouts = FinancialPayoutProvider(
      service: FinancialPayoutService(
        repository: FakeFinancialPayoutRepository(),
      ),
    );
    addTearDown(payouts.dispose);
    await payouts.load();
    final FinancialDepositProvider deposits = FinancialDepositProvider(
      service: FinancialDepositService(
        repository: FakeFinancialDepositRepository(),
      ),
    );
    addTearDown(deposits.dispose);
    await deposits.load();
    return <SingleChildWidget>[
      ChangeNotifierProvider<EarningsProvider>.value(value: summary),
      ChangeNotifierProvider<TransactionHistoryProvider>.value(
        value: history,
      ),
      ChangeNotifierProvider<FinancialPayoutProvider>.value(value: payouts),
      ChangeNotifierProvider<FinancialDepositProvider>.value(value: deposits),
    ];
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    FakeEarningsRepository? repository,
    bool dark = false,
  }) async {
    // Tall viewport: the dashboard is a long scroll and slivers build
    // lazily — the full content must be laid out for assertions.
    await pumpScreen(
      tester,
      const EarningsDashboardScreen(),
      height: 1600,
      dark: dark,
      providers: await dashboardProviders(repository: repository),
    );
    await tester.pumpAndSettle();
  }

  EarningsSummary zeroSummary() => seedEarningsSummary(
    available: 0,
    held: 0,
    pending: 0,
    lifetimeEarned: 0,
    releaseCount: 0,
    completedContracts: 0,
    totalWithdrawn: 0,
    monthly: <EarningsMonthBucket>[],
  );

  group('EarningsDashboardScreen', () {
    testWidgets('renders the live summary, chart, and recent activity', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repo = FakeEarningsRepository();
      repo.setSummary('NGN', seedEarningsSummary());
      repo.setPage(seedEarningsPage());
      await pumpDashboard(tester, repository: repo);

      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Lifetime earned'), findsOneWidget);
      expect(find.text('Server-verified figures'), findsOneWidget);
      expect(find.text('Monthly earnings'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Milestone payment'), findsOneWidget);
      expect(find.text('View full history'), findsOneWidget);
    });

    testWidgets('shows the frozen banner when escrows are disputed', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repo = FakeEarningsRepository();
      repo.setSummary('NGN', seedEarningsSummary(frozenCount: 2));
      repo.setPage(seedEarningsPage());
      await pumpDashboard(tester, repository: repo);

      expect(find.textContaining('frozen'), findsOneWidget);
    });

    testWidgets('shows honest zeros for a new professional', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repo = FakeEarningsRepository();
      repo.setSummary('NGN', zeroSummary());
      await pumpDashboard(tester, repository: repo);

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('No earnings yet.'), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('draws on the dark theme', (WidgetTester tester) async {
      final FakeEarningsRepository repo = FakeEarningsRepository();
      repo.setSummary('NGN', seedEarningsSummary());
      repo.setPage(seedEarningsPage());
      await pumpDashboard(tester, repository: repo, dark: true);

      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
    });
  });
}
