import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/documents/screens/contract_list_screen.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_service_contract.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  ServiceContractProvider providerWith(FakeServiceContractRepository repo) {
    final ContractService service = ContractService(repository: repo);
    return ServiceContractProvider(service: service);
  }

  List<SingleChildWidget> providers(ServiceContractProvider provider) =>
      <SingleChildWidget>[
        ChangeNotifierProvider<ServiceContractProvider>.value(value: provider),
      ];

  group('ContractListScreen', () {
    testWidgets('shows empty state when no contracts', (
      WidgetTester tester,
    ) async {
      final ServiceContractProvider provider = providerWith(
        FakeServiceContractRepository(seed: const <ServiceContract>[]),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const ContractListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('No contracts yet'), findsOneWidget);
    });

    testWidgets('renders one row per contract with status badges', (
      WidgetTester tester,
    ) async {
      final ServiceContractProvider provider = providerWith(
        FakeServiceContractRepository(
          seed: <ServiceContract>[
            FakeServiceContractRepository.contract(
              id: 'c1',
              status: 'offered',
            ),
            FakeServiceContractRepository.contract(
              id: 'c2',
              status: 'active',
            ),
          ],
        ),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const ContractListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ContractStatusBadge), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Offered'), findsWidgets);
    });

    testWidgets('status chip filters via p_status', (
      WidgetTester tester,
    ) async {
      final FakeServiceContractRepository repo =
          FakeServiceContractRepository(
            seed: <ServiceContract>[
              FakeServiceContractRepository.contract(
                id: 'c1',
                status: 'offered',
              ),
            ],
          );
      final ServiceContractProvider provider = providerWith(repo);
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const ContractListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      expect(repo.lastStatus, 'active');
    });
  });
}
