import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/systems/finance/screens/transaction_history_screen.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_earnings_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  Future<TransactionHistoryProvider> providerWith(
    FakeEarningsRepository repository,
  ) async {
    final TransactionHistoryProvider provider = TransactionHistoryProvider(
      service: ServiceEarningsService(repository: repository),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  Future<void> pumpHistory(
    WidgetTester tester,
    FakeEarningsRepository repository, {
    String? contractId,
  }) async {
    final TransactionHistoryProvider provider = await providerWith(
      repository,
    );
    await pumpScreen(
      tester,
      TransactionHistoryScreen(contractId: contractId),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TransactionHistoryProvider>.value(
          value: provider,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('TransactionHistoryScreen', () {
    testWidgets('renders filter chips, currency, and live rows', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setPage(seedEarningsPage());
      await pumpHistory(tester, repository);

      expect(find.text('Transaction history'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('Withdrawn'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Frozen'), findsOneWidget);
      expect(find.text('Milestone payment'), findsOneWidget);
      expect(find.text('Withdrawal'), findsOneWidget);
    });

    testWidgets('filter chips drive the server filter and reload', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setPage(seedEarningsPage());
      await pumpHistory(tester, repository);

      await tester.tap(find.text('Earned'));
      await tester.pumpAndSettle();

      expect(repository.lastType, EarningsHistoryFilter.earned);
    });

    testWidgets('shows the honest empty state with no rows', (
      WidgetTester tester,
    ) async {
      await pumpHistory(tester, FakeEarningsRepository());

      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('shows the error state with retry on failure', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.nextError = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'offline',
      );
      await pumpHistory(tester, repository);

      expect(find.text('Failed to load history'), findsOneWidget);
    });

    testWidgets('renders the date-range filter and clears it', (
      WidgetTester tester,
    ) async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setPage(seedEarningsPage());
      final TransactionHistoryProvider preset = await providerWith(
        repository,
      );
      await preset.setDateRange(DateTime(2026, 9, 1), DateTime(2026, 10, 31));
      await pumpScreen(
        tester,
        const TransactionHistoryScreen(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TransactionHistoryProvider>.value(
            value: preset,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('From 1 Sep 2026'), findsOneWidget);
      expect(find.text('To 31 Oct 2026'), findsOneWidget);

      await tester.tap(find.text('Clear dates'));
      await tester.pumpAndSettle();

      expect(preset.dateFrom, isNull);
      expect(preset.dateTo, isNull);
      expect(find.text('From date'), findsOneWidget);
    });
  });
}
