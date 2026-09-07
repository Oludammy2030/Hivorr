import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/support/screens/dispute_list_screen.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

class _HangingDisputeRepository extends FakeDisputeRepository {
  @override
  Future<List<DisputeCase>> listDisputes({String? status}) =>
      Completer<List<DisputeCase>>().future;
}

void main() {
  DisputeProvider providerWith(DisputeRepository repository) => DisputeProvider(
        service: DisputeService(repository: repository),
      );

  Future<void> pumpList(
    WidgetTester tester,
    DisputeProvider provider, {
    required GoRouter router,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DisputeProvider>.value(
        value: provider,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme,
        ),
      ),
    );
  }

  List<SingleChildWidget> providers(DisputeProvider provider) =>
      <SingleChildWidget>[
        ChangeNotifierProvider<DisputeProvider>.value(value: provider),
      ];

  group('DisputeListScreen', () {
    testWidgets('renders the Disputes app bar title',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Disputes'), findsOneWidget);
    });

    testWidgets('shows HivorrLoadingState while the list is pending',
        (WidgetTester tester) async {
      final provider = providerWith(_HangingDisputeRepository());
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      expect(find.text('Loading disputes...'), findsOneWidget);
    });

    testWidgets('renders one card per dispute with status badge + date',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(
            id: 'dispute-1',
            disputeType: 'milestone_disagreement',
            status: 'open',
            filedAt: DateTime(2026, 8, 26),
          ),
          seedDisputeCaseEntity(
            id: 'dispute-2',
            disputeType: 'fraud',
            status: 'under_review',
          ),
        ],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Milestone disagreement'), findsOneWidget);
      expect(find.text('Fraud'), findsOneWidget);
      // "Under review" appears both as a filter chip and a status badge.
      expect(find.text('Open'), findsWidgets);
      expect(find.text('Under review'), findsNWidgets(2));
    });

    testWidgets('shows HivorrEmptyState when no disputes exist',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('No disputes yet'), findsOneWidget);
      expect(
        find.textContaining('Raise one from an escrow’s dispute action'),
        findsOneWidget,
      );
    });

    testWidgets('shows HivorrErrorState on read failure',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.forbidden,
          message: 'Not allowed',
          code: 'PLT002',
        );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(find.text('Failed to load disputes'), findsOneWidget);
      expect(find.text('Not allowed'), findsOneWidget);
    });

    testWidgets('filtering by a status re-queries with the filter',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(id: 'dispute-1', status: 'open'),
          seedDisputeCaseEntity(
            id: 'dispute-2',
            status: 'under_review',
            disputeType: 'fraud',
          ),
        ],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      final int initialCalls = repository.listCallCount;

      // Tap the filter chip (the first "Under review" is the chip row; the
      // second is a status badge).
      await tester.tap(find.text('Under review').first);
      await tester.pumpAndSettle();

      expect(repository.listCallCount, greaterThan(initialCalls));
      expect(repository.lastStatusFilter, 'under_review');
      // Only the matching card remains: the fraud card (with its badge), while
      // the open service-quality card is filtered out.
      expect(find.text('Fraud'), findsOneWidget);
      expect(find.text('Service quality'), findsNothing);
    });

    testWidgets('pull-to-refresh reloads the list',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository(
        cases: <DisputeCase>[seedDisputeCaseEntity()],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeListScreen(),
        providers: providers(provider),
      );
      await tester.pumpAndSettle();
      final int initial = repository.listCallCount;

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(repository.listCallCount, greaterThan(initial));
    });

    testWidgets('tapping a card pushes the dispute detail route',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository(
        cases: <DisputeCase>[seedDisputeCaseEntity(id: 'dispute-9')],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.disputes,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.disputes,
            builder: (_, _) => const DisputeListScreen(),
          ),
          GoRoute(
            path: RoutePaths.disputeDetail,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('detail-screen'))),
          ),
        ],
      );

      await pumpList(tester, provider, router: router);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Service quality'));
      await tester.pumpAndSettle();

      expect(find.text('detail-screen'), findsOneWidget);
    });
  });
}