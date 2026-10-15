import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/systems/documents/screens/contract_detail_screen.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/finance/widgets/escrow_dispute_banner.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';
import 'package:hivorr/systems/support/screens/dispute_detail_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_filing_screen.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/fakes/fake_service_contract.dart';
import '../../support/fakes/support/fake_dispute_repository.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  ServiceContractProvider providerWith(FakeServiceContractRepository repo) {
    final ContractService service = ContractService(repository: repo);
    return ServiceContractProvider(service: service);
  }

  List<SingleChildWidget> providers(
    ServiceContractProvider provider, {
    FakeAuthProvider? auth,
  }) => <SingleChildWidget>[
    ChangeNotifierProvider<ServiceContractProvider>.value(value: provider),
    Provider<ContractService>.value(
      value: ContractService(
        repository: FakeServiceContractRepository(
          seed: const <ServiceContract>[],
        ),
      ),
    ),
    if (auth != null) ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];

  FakeAuthProvider authedAs(String entityId) {
    final FakeAuthProvider auth = FakeAuthProvider(
      initialStatus: AuthStatus.authenticated,
    );
    auth.sessionOverride = AuthSession(entityId: entityId);
    return auth;
  }

  group('ContractDetailScreen', () {
    testWidgets('professional sees Accept on offered contract', (
      WidgetTester tester,
    ) async {
      final provider = providerWith(
        FakeServiceContractRepository(
          seed: [
            FakeServiceContractRepository.contract(
              id: 'c1',
              status: 'offered',
              clientId: 'client-1',
              professionalId: 'pro-1',
            ),
          ],
        ),
      );
      addTearDown(provider.dispose);
      final auth = authedAs('pro-1');
      addTearDown(auth.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MilestoneListCard), findsOneWidget);
      expect(find.text('Accept offer'), findsOneWidget);
      expect(find.byType(ContractStatusBadge), findsWidgets);
    });

    testWidgets('client sees Verify on completed milestone', (
      WidgetTester tester,
    ) async {
      final provider = providerWith(
        FakeServiceContractRepository(
          seed: [
            FakeServiceContractRepository.contract(
              id: 'c1',
              status: 'active',
              clientId: 'client-1',
              professionalId: 'pro-1',
            ),
          ],
        ),
      );
      addTearDown(provider.dispose);
      final auth = authedAs('client-1');
      addTearDown(auth.dispose);

      // Mark m1 completed through the fake before pumping.
      await provider
          .completeMilestone(contractId: 'c1', milestoneId: 'm1');
      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify'), findsWidgets);
      expect(find.text('Request revision'), findsWidgets);
    });

    testWidgets('stranger sees guidance card, not role actions', (
      WidgetTester tester,
    ) async {
      final provider = providerWith(
        FakeServiceContractRepository(
          seed: <ServiceContract>[
            FakeServiceContractRepository.contract(id: 'c1', status: 'active'),
          ],
        ),
      );
      addTearDown(provider.dispose);
      final auth = authedAs('stranger-9');
      addTearDown(auth.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept offer'), findsNothing);
      expect(find.text('Verify'), findsNothing);
      expect(
        find.text('Contract actions are unavailable right now'),
        findsOneWidget,
      );
    });

    testWidgets('disputed contract shows frozen banner', (
      WidgetTester tester,
    ) async {
      final provider = providerWith(
        FakeServiceContractRepository(
          seed: [
            FakeServiceContractRepository.contract(
              id: 'c1',
              status: 'disputed',
            ),
          ],
        ),
      );
      addTearDown(provider.dispose);
      final auth = authedAs('client-1');
      addTearDown(auth.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EscrowDisputeBanner), findsOneWidget);
      expect(find.text('Accept offer'), findsNothing);
    });

    testWidgets('disputed banner routes to the open dispute case', (
      WidgetTester tester,
    ) async {
      final contracts = providerWith(
        FakeServiceContractRepository(
          seed: [
            FakeServiceContractRepository.contract(
              id: 'c9',
              status: 'disputed',
            ),
          ],
        ),
      );
      addTearDown(contracts.dispose);
      final auth = authedAs('client-1');
      addTearDown(auth.dispose);
      final disputes = DisputeProvider(
        service: DisputeService(
          repository: FakeDisputeRepository(
            cases: [
              seedDisputeCaseEntity(
                id: 'd-open',
                escrowId: '',
                contractId: 'c9',
                status: 'open',
              ),
            ],
          ),
        ),
      );
      addTearDown(disputes.dispose);
      final GoRouter router = GoRouter(
        initialLocation: '/contracts/c9',
        routes: <RouteBase>[
          GoRoute(
            path: '/contracts/:id',
            builder: (BuildContext context, GoRouterState state) =>
                ContractDetailScreen(
                  contractId: state.pathParameters['id'] ?? '',
                ),
          ),
          GoRoute(
            path: '/support/disputes/:id',
            builder: (BuildContext context, GoRouterState state) =>
                DisputeDetailScreen(
                  caseId: state.pathParameters['id'] ?? '',
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<ServiceContractProvider>.value(
              value: contracts,
            ),
            Provider<ContractService>.value(
              value: ContractService(
                repository: FakeServiceContractRepository(
                  seed: const <ServiceContract>[],
                ),
              ),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<DisputeProvider>.value(value: disputes),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View dispute'), findsOneWidget);
      await tester.tap(find.text('View dispute'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Dispute'), findsOneWidget);
    });

    testWidgets('disputed banner falls back to filing without an open case', (
      WidgetTester tester,
    ) async {
      final contracts = providerWith(
        FakeServiceContractRepository(
          seed: [
            FakeServiceContractRepository.contract(
              id: 'c9',
              status: 'disputed',
            ),
          ],
        ),
      );
      addTearDown(contracts.dispose);
      final auth = authedAs('client-1');
      addTearDown(auth.dispose);
      final disputes = DisputeProvider(
        service: DisputeService(
          repository: FakeDisputeRepository(
            cases: [
              seedDisputeCaseEntity(
                id: 'd-old',
                escrowId: '',
                contractId: 'c9',
                status: 'withdrawn',
              ),
            ],
          ),
        ),
      );
      addTearDown(disputes.dispose);
      final GoRouter router = GoRouter(
        initialLocation: '/contracts/c9',
        routes: <RouteBase>[
          GoRoute(
            path: '/contracts/:id',
            builder: (BuildContext context, GoRouterState state) =>
                ContractDetailScreen(
                  contractId: state.pathParameters['id'] ?? '',
                ),
          ),
          GoRoute(
            path: '/support/disputes/file-by-contract/:contractId',
            builder: (BuildContext context, GoRouterState state) =>
                DisputeFilingScreen(
                  contractId: state.pathParameters['contractId'] ?? '',
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<ServiceContractProvider>.value(
              value: contracts,
            ),
            Provider<ContractService>.value(
              value: ContractService(
                repository: FakeServiceContractRepository(
                  seed: const <ServiceContract>[],
                ),
              ),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<DisputeProvider>.value(value: disputes),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View dispute'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'File dispute'), findsOneWidget);
    });

    testWidgets('unknown contract renders not-found empty state', (
      WidgetTester tester,
    ) async {
      final provider = providerWith(
        FakeServiceContractRepository(seed: const <ServiceContract>[]),
      );
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'missing'),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      // Fake mirrors the server `PLT004` oracle → provider error state →
      // not-found empty state (identical for foreign/unknown).
      expect(find.byType(MilestoneListCard), findsNothing);
      expect(find.text('Contract not found'), findsOneWidget);
    });
  });

  group('ContractDetailScreen scheduling entry (EP-03-14)', () {
    Future<void> pumpContract(
      WidgetTester tester, {
      required String status,
      required String viewerId,
    }) async {
      final provider = providerWith(
        FakeServiceContractRepository(
          seed: [
            FakeServiceContractRepository.contract(
              id: 'c1',
              status: status,
              clientId: 'client-1',
              professionalId: 'pro-1',
            ),
          ],
        ),
      );
      addTearDown(provider.dispose);
      final auth = authedAs(viewerId);
      addTearDown(auth.dispose);
      await pumpApp(
        tester,
        const ContractDetailScreen(contractId: 'c1'),
        providers: providers(provider, auth: auth),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('participant on active contract sees booking entry', (
      WidgetTester tester,
    ) async {
      await pumpContract(tester, status: 'active', viewerId: 'client-1');
      expect(find.text('Book appointment'), findsOneWidget);
    });

    testWidgets('professional sees availability entry', (
      WidgetTester tester,
    ) async {
      await pumpContract(tester, status: 'active', viewerId: 'pro-1');
      expect(find.text('Manage availability'), findsOneWidget);
    });

    testWidgets('stranger sees participant guidance, never booking', (
      WidgetTester tester,
    ) async {
      await pumpContract(tester, status: 'active', viewerId: 'stranger-9');
      expect(
        find.text(
          'Scheduling is available to contract participants. '
          'You are not a participant on this contract.',
        ),
        findsOneWidget,
      );
      expect(find.text('Book appointment'), findsNothing);
    });

    testWidgets('participant on offered contract sees inactive guidance', (
      WidgetTester tester,
    ) async {
      await pumpContract(tester, status: 'offered', viewerId: 'client-1');
      expect(
        find.textContaining(
          'Appointments open once the contract is active.',
        ),
        findsOneWidget,
      );
      expect(find.text('Book appointment'), findsNothing);
    });
  });
}
