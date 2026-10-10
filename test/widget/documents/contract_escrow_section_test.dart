import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/systems/documents/screens/contract_detail_screen.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/fakes/fake_contract_escrow.dart';
import '../../support/fakes/fake_service_contract.dart';
import '../../support/fakes/finance/fake_earnings_repository.dart';
import '../../support/fakes/finance/fake_escrow_repository.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  ContractEscrowOrchestrator orchestratorWith({
    required ServiceContract contract,
    bool writeAvailable = true,
  }) {
    final FakeServiceContractRepository contracts =
        FakeServiceContractRepository(seed: <ServiceContract>[contract]);
    final FakeEscrowRepository escrows = FakeEscrowRepository(
      writeAvailable: writeAvailable,
    );
    return ContractEscrowOrchestrator(
      contracts: ContractService(repository: contracts),
      escrows: EscrowService(repository: escrows),
    );
  }

  List<SingleChildWidget> providers(
    ServiceContractProvider provider,
    ContractEscrowOrchestrator? orchestrator, {
    FakeAuthProvider? auth,
    EarningsProvider? earnings,
  }) => <SingleChildWidget>[
    ChangeNotifierProvider<ServiceContractProvider>.value(value: provider),
    if (orchestrator != null)
      Provider<ContractEscrowOrchestrator>.value(value: orchestrator),
    if (auth != null) ChangeNotifierProvider<AuthProvider>.value(value: auth),
    if (earnings != null)
      ChangeNotifierProvider<EarningsProvider>.value(value: earnings),
  ];

  FakeAuthProvider authedAs(String entityId) {
    final FakeAuthProvider auth = FakeAuthProvider(
      initialStatus: AuthStatus.authenticated,
    );
    auth.sessionOverride = AuthSession(entityId: entityId);
    return auth;
  }

  ServiceContractProvider providerFor(ServiceContract contract) {
    final FakeServiceContractRepository repo = FakeServiceContractRepository(
      seed: <ServiceContract>[contract],
    );
    return ServiceContractProvider(
      service: ContractService(repository: repo),
    );
  }

  /// Active, linked contract whose first milestone is `completed` (client
  /// verification pending) with a future review deadline.
  ServiceContract linkedCompleted() {
    final ServiceContract base = seedLinkedContract(
      id: 'c1',
      status: 'active',
    );
    final List<ContractMilestone> milestones = <ContractMilestone>[
      seedUnexpiredMilestone(id: 'm1'),
      ...base.milestones.where(
        (ContractMilestone m) => m.id != 'm1',
      ),
    ];
    return ServiceContract(
      id: base.id,
      serviceListingId: base.serviceListingId,
      clientEntityId: base.clientEntityId,
      professionalEntityId: base.professionalEntityId,
      status: base.status,
      escrowId: base.escrowId,
      totalAmount: base.totalAmount,
      currencyCode: base.currencyCode,
      milestones: milestones,
      events: base.events,
    );
  }

  group('ContractDetailScreen escrow section (EP-03-11)', () {
    testWidgets('client sees Verify & release + amount + View escrow', (
      WidgetTester tester,
    ) async {
      final ServiceContract contract = linkedCompleted();
      final ServiceContractProvider provider = providerFor(contract);
      addTearDown(provider.dispose);
      final FakeAuthProvider auth = authedAs('client-1');
      addTearDown(auth.dispose);
      final ContractEscrowOrchestrator orchestrator = orchestratorWith(
        contract: contract,
      );

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, orchestrator, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify & release'), findsOneWidget);
      expect(find.textContaining('Releases'), findsWidgets);
      expect(find.text('View escrow'), findsWidgets);
    });

    testWidgets('Verify & release completes the orchestrator sequence', (
      WidgetTester tester,
    ) async {
      final ServiceContract contract = linkedCompleted();
      final ServiceContractProvider provider = providerFor(contract);
      addTearDown(provider.dispose);
      final FakeAuthProvider auth = authedAs('client-1');
      addTearDown(auth.dispose);
      final ContractEscrowOrchestrator orchestrator = orchestratorWith(
        contract: contract,
      );

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, orchestrator, auth: auth),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Verify & release'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify & release'));
      await tester.pumpAndSettle();

      expect(find.text('Milestone released.'), findsOneWidget);
    });

    testWidgets('no Verify & release without an orchestrator', (
      WidgetTester tester,
    ) async {
      final ServiceContract contract = linkedCompleted();
      final ServiceContractProvider provider = providerFor(contract);
      addTearDown(provider.dispose);
      final FakeAuthProvider auth = authedAs('client-1');
      addTearDown(auth.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, null, auth: auth),
      );
      await tester.pumpAndSettle();

      // Verify-only actions remain; the combined release action is hidden.
      expect(find.text('Verify & release'), findsNothing);
      expect(find.text('Verify'), findsWidgets);
    });

    testWidgets('unlinked contract shows Funding pending', (
      WidgetTester tester,
    ) async {
      final ServiceContract contract =
          FakeServiceContractRepository.contract(id: 'c1', status: 'active');
      final ServiceContractProvider provider = providerFor(contract);
      addTearDown(provider.dispose);
      final FakeAuthProvider auth = authedAs('client-1');
      addTearDown(auth.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, null, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.text('Funding pending'), findsOneWidget);
      expect(find.text('Verify & release'), findsNothing);
    });

    testWidgets('release refreshes the earnings windows (EP-03-16 hook)', (
      WidgetTester tester,
    ) async {
      final ServiceContract contract = linkedCompleted();
      final ServiceContractProvider provider = providerFor(contract);
      addTearDown(provider.dispose);
      final FakeAuthProvider auth = authedAs('client-1');
      addTearDown(auth.dispose);
      final ContractEscrowOrchestrator orchestrator = orchestratorWith(
        contract: contract,
      );
      final FakeEarningsRepository earningsRepo = FakeEarningsRepository();
      earningsRepo.setSummary('NGN', seedEarningsSummary());
      final EarningsProvider earnings = EarningsProvider(
        service: ServiceEarningsService(repository: earningsRepo),
      );
      addTearDown(earnings.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(
          provider,
          orchestrator,
          auth: auth,
          earnings: earnings,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Verify & release'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify & release'));
      await tester.pumpAndSettle();

      expect(find.text('Milestone released.'), findsOneWidget);
      expect(earningsRepo.summaryCallCount, greaterThan(0));
      expect(earningsRepo.invalidateCallCount, 1);
    });
  });
}
