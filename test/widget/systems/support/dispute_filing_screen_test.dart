import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/screens/dispute_filing_screen.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_escrow_repository.dart';
import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  DisputeProvider providerWith(DisputeRepository repository) =>
      DisputeProvider(service: DisputeService(repository: repository));

  Future<void> pumpFiling(
    WidgetTester tester,
    DisputeProvider provider, {
    GoRouter? router,
    EscrowDetail? escrowDetail,
  }) async {
    final EscrowProvider escrowProvider = EscrowProvider(
      service: EscrowService(
        repository: FakeEscrowRepository(
          detail: escrowDetail ?? seedEscrowDetailEntity(id: 'escrow-abc'),
        ),
      ),
    );
    addTearDown(escrowProvider.dispose);
    final Widget child = const DisputeFilingScreen(escrowId: 'escrow-abc');
    if (router == null) {
      await pumpApp(
        tester,
        child,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<EscrowProvider>.value(value: escrowProvider),
          ChangeNotifierProvider<DisputeProvider>.value(value: provider),
        ],
      );
      await tester.pump();
    } else {
      // pumpApp wraps in a Scaffold/home; for router use, build directly.
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<EscrowProvider>.value(value: escrowProvider),
            ChangeNotifierProvider<DisputeProvider>.value(value: provider),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pump();
    }
  }

  Future<void> selectType(WidgetTester tester, String label) async {
    await tester.tap(find.text('Dispute type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterReason(WidgetTester tester, String reason) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason'),
      reason,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byType(HivorrButton),
      matching: find.text('File dispute'),
    ));
    await tester.pumpAndSettle();
  }

  HivorrButton submitWidget(WidgetTester tester) => tester.widget<HivorrButton>(
        find.byType(HivorrButton),
      );

  Future<void> tapDropdown(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    // The label sits inside the dropdown's InputDecorator; the decorated field
    // receives the pointer, so silence the strict text hit-test warning.
    await tester.tap(find.text(label), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group('DisputeFilingScreen', () {
    testWidgets('renders the File dispute app bar and the freeze copy',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);

      expect(find.widgetWithText(AppBar, 'File dispute'), findsOneWidget);
      expect(
        find.textContaining('Filing freezes escrow ${idRefSuffix('escrow-abc')}'),
        findsOneWidget,
      );
    });

    testWidgets('offers the 5-type dispute vocabulary',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);

      await tester.tap(find.text('Dispute type'));
      await tester.pumpAndSettle();

      for (final String label in <String>[
        'Service quality',
        'Non-delivery',
        'Milestone disagreement',
        'Fraud',
        'Other',
      ]) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('submit is disabled until a type and valid reason are chosen',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);

      HivorrButton submit() => submitWidget(tester);
      expect(submit().onPressed, isNull);

      await selectType(tester, 'Fraud');
      await tester.pump();
      expect(submit().onPressed, isNull); // reason still empty

      await enterReason(tester, 'A valid reason that is long enough.');
      await tester.pump();
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('a too-short reason keeps submit disabled',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);
      await selectType(tester, 'Fraud');
      await enterReason(tester, 'short');

      expect(submitWidget(tester).onPressed, isNull);
    });

    testWidgets('filing passes the type, reason, priority and outcome',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);
      await selectType(tester, 'Milestone disagreement');
      await enterReason(tester, 'Work did not match the agreed milestone.');
      // Pick a priority of High.
      await tapDropdown(tester, 'Priority');
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      // Pick desired outcome Split.
      await tapDropdown(tester, 'Desired outcome (optional)');
      await tester.tap(find.text('Split the amount').last);
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      expect(repository.fileCallCount, 1);
      expect(repository.lastEscrowId, 'escrow-abc');
      expect(repository.lastDisputeType, 'milestone_disagreement');
      expect(repository.lastReason, 'Work did not match the agreed milestone.');
      expect(repository.lastPriority, 'high');
      expect(repository.lastDesiredOutcome, 'split');
    });

    testWidgets('defaults priority to medium when not chosen',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);
      await selectType(tester, 'Fraud');
      await enterReason(tester, 'A valid reason that is long enough');

      await tapSubmit(tester);

      expect(repository.lastPriority, 'medium');
      expect(repository.lastDesiredOutcome, isNull);
    });

    testWidgets('navigates to the dispute detail after a successful filing',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.disputesNew.replaceAll(':escrowId', 'escrow-abc'),
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.disputesNew,
            builder: (_, _) => const DisputeFilingScreen(escrowId: 'escrow-abc'),
          ),
          GoRoute(
            path: RoutePaths.disputeDetail,
            builder: (_, _) => const Scaffold(
              body: Center(child: Text('filed-detail')),
            ),
          ),
        ],
      );

      await pumpFiling(tester, provider, router: router);
      await selectType(tester, 'Fraud');
      await enterReason(tester, 'A valid reason that is long enough');

      await tapSubmit(tester);

      expect(find.text('filed-detail'), findsOneWidget);
    });

    testWidgets('shows a submit error when filing fails',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);
      await selectType(tester, 'Fraud');
      await enterReason(tester, 'A valid reason that is long enough');

      await tapSubmit(tester);

      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('the reason field shows the 10-character helper hint',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);

      expect(
        find.text('At least 10 characters so the reviewer has context.'),
        findsOneWidget,
      );
    });

    testWidgets('an already-disputed escrow shows the conflict banner and '
        'disables submit', (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpFiling(
        tester,
        provider,
        escrowDetail: seedEscrowDetailEntity(
          id: 'escrow-abc',
          status: 'disputed',
        ),
      );
      await selectType(tester, 'Fraud');
      await enterReason(tester, 'A valid reason that is long enough');

      expect(
        find.text('An active dispute already exists for this escrow.'),
        findsOneWidget,
      );
      expect(submitWidget(tester).onPressed, isNull);
      // The guard must never reach the RPC for a case that can never be filed.
      expect(repository.fileCallCount, 0);
    });

    testWidgets('a non-disputed escrow shows no conflict banner and can submit',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpFiling(
        tester,
        provider,
        escrowDetail: seedEscrowDetailEntity(
          id: 'escrow-abc',
          status: 'funded',
        ),
      );
      await selectType(tester, 'Fraud');
      await enterReason(tester, 'A valid reason that is long enough');

      expect(
        find.text('An active dispute already exists for this escrow.'),
        findsNothing,
      );
      expect(submitWidget(tester).onPressed, isNotNull);
    });

    testWidgets('labels the submit button "File dispute"',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository());
      addTearDown(provider.dispose);

      await pumpFiling(tester, provider);

      // AppBar title + button label both read "File dispute".
      expect(find.text('File dispute'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(HivorrButton),
          matching: find.text('File dispute'),
        ),
        findsOneWidget,
      );
    });
  });
}