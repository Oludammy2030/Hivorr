import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/screens/contract_earnings_detail_screen.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_service_contract.dart';
import '../../../support/fakes/finance/fake_earnings_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    String contractId = 'c1',
    String status = 'active',
    bool withHistory = true,
  }) async {
    final FakeEarningsRepository earningsRepo = FakeEarningsRepository();
    if (withHistory) {
      earningsRepo.setPage(seedEarningsPage());
    }
    final TransactionHistoryProvider history = TransactionHistoryProvider(
      service: ServiceEarningsService(repository: earningsRepo),
    );
    addTearDown(history.dispose);
    final ServiceContractProvider contracts = ServiceContractProvider(
      service: ContractService(
        repository: FakeServiceContractRepository(
          seed: <ServiceContract>[
            FakeServiceContractRepository.contract(
              id: contractId,
              status: status,
            ),
          ],
        ),
      ),
    );
    addTearDown(contracts.dispose);
    await pumpScreen(
      tester,
      ContractEarningsDetailScreen(contractId: contractId),
      // Tall viewport: milestones plus ledger exceed a phone fold and
      // slivers build lazily.
      height: 1600,
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ServiceContractProvider>.value(
          value: contracts,
        ),
        ChangeNotifierProvider<TransactionHistoryProvider>.value(
          value: history,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('ContractEarningsDetailScreen', () {
    testWidgets('renders milestones, actions, and the ledger', (
      WidgetTester tester,
    ) async {
      await pumpDetail(tester);

      expect(find.text('Contract earnings'), findsOneWidget);
      expect(find.text('Milestones'), findsWidgets);
      expect(find.text('Ledger'), findsOneWidget);
      expect(find.text('View contract'), findsOneWidget);
      expect(find.text('Milestone payment'), findsOneWidget);
    });

    testWidgets('shows the frozen banner for disputed contracts', (
      WidgetTester tester,
    ) async {
      await pumpDetail(tester, status: 'disputed');

      expect(find.textContaining('frozen'), findsOneWidget);
    });

    testWidgets('shows the honest ledger empty state with no rows', (
      WidgetTester tester,
    ) async {
      await pumpDetail(tester, withHistory: false);

      expect(find.text('No ledger rows yet'), findsOneWidget);
    });
  });
}
