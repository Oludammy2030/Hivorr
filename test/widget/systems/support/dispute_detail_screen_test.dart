import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/screens/dispute_detail_screen.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

class _HangingDisputeRepository extends FakeDisputeRepository {
  @override
  Future<DisputeCaseDetail> getCase(String caseId) =>
      Completer<DisputeCaseDetail>().future;
}

DisputeCaseDetail detail({
  String id = 'dispute-1',
  String status = 'open',
  String disputeType = 'service_quality',
  String priority = 'medium',
  String? desiredOutcome,
  String reason = 'The delivered work missed the agreed milestone.',
  String escrowId = 'escrow-abc',
  List<DisputeEvidence> evidence = const <DisputeEvidence>[],
  DisputeResolution? resolution,
}) =>
    seedDisputeDetailEntity(
      id: id,
      status: status,
      evidence: evidence,
      resolution: resolution,
    ).withCase(
      seedDisputeCaseEntity(
        id: id,
        status: status,
        disputeType: disputeType,
        priority: priority,
        desiredOutcome: desiredOutcome,
        reason: reason,
        escrowId: escrowId,
      ),
    );

void main() {
  DisputeProvider providerWith(DisputeRepository repository) =>
      DisputeProvider(service: DisputeService(repository: repository));

  Future<void> pumpDetail(
    WidgetTester tester,
    DisputeProvider provider, {
    Widget? screen,
    GoRouter? router,
  }) async {
    final Widget child = screen ?? const DisputeDetailScreen(caseId: 'dispute-1');
    if (router == null) {
      await pumpApp(
        tester,
        child,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<DisputeProvider>.value(value: provider),
        ],
      );
      await tester.pumpAndSettle();
    } else {
      await tester.pumpWidget(
        ChangeNotifierProvider<DisputeProvider>.value(
          value: provider,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  group('DisputeDetailScreen', () {
    testWidgets('renders the Dispute app bar title',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail(id: 'dispute-1')),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.widgetWithText(AppBar, 'Dispute'), findsOneWidget);
    });

    testWidgets('shows HivorrLoadingState while loading',
        (WidgetTester tester) async {
      final provider = providerWith(_HangingDisputeRepository());
      addTearDown(provider.dispose);

      await pumpApp(
        tester,
        const DisputeDetailScreen(caseId: 'dispute-1'),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<DisputeProvider>.value(value: provider),
        ],
      );
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      expect(find.text('Loading dispute...'), findsOneWidget);
    });

    testWidgets('shows HivorrErrorState on read failure',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Missing',
          code: 'PLT004',
        );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(find.text('Failed to load dispute'), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);
    });

    testWidgets('renders the case header with type badge and idRef suffix',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(
          detail: detail(
            id: 'dispute-1',
            status: 'under_review',
            disputeType: 'milestone_disagreement',
          ),
        ),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Milestone disagreement'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('Case ${idRefSuffix('dispute-1')}'), findsOneWidget);
    });

    testWidgets('renders the filed reason card',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(
          detail: detail(reason: 'The delivered work missed the milestone.'),
        ),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Reason'), findsOneWidget);
      expect(
        find.text('The delivered work missed the milestone.'),
        findsOneWidget,
      );
    });

    testWidgets('renders the priority and outcome meta chips',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail(priority: 'high', desiredOutcome: 'split')),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Priority: High'), findsOneWidget);
      expect(find.text('Outcome: Split the amount'), findsOneWidget);
    });

    testWidgets('shows the View escrow action when onViewEscrow provided',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail()),
      );
      addTearDown(provider.dispose);
      bool viewed = false;

      await pumpDetail(
        tester,
        provider,
        screen: DisputeDetailScreen(
          caseId: 'dispute-1',
          onViewEscrow: () => viewed = true,
        ),
      );

      await tester.tap(find.text('View escrow ${idRefSuffix('escrow-abc')}'));
      expect(viewed, isTrue);
    });

    testWidgets('renders ordered evidence cards with preview hooks',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(
          detail: detail(
            evidence: <DisputeEvidence>[
              seedDisputeEvidenceEntity(
                id: 'ev-1',
                title: 'Mismatch screenshot',
                fileUrl: 'entity-filer/dispute-1/shot.png',
                fileMetadata: <String, dynamic>{
                  'originalName': 'shot.png',
                },
              ),
              seedDisputeEvidenceEntity(
                id: 'ev-2',
                title: 'Written account',
                evidenceType: 'description',
                description: 'Full details.',
              ),
            ],
          ),
        ),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Evidence (2)'), findsOneWidget);
      expect(find.text('Mismatch screenshot'), findsOneWidget);
      expect(find.text('Written account'), findsOneWidget);
      expect(find.text('Full details.'), findsOneWidget);
    });

    testWidgets('shows the no-evidence copy when the case has none',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail()),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Evidence (0)'), findsOneWidget);
      expect(find.textContaining('No evidence yet'), findsOneWidget);
    });

    testWidgets('renders the resolution outcome when bound',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(
          detail: detail(
            status: 'resolved',
            resolution: seedDisputeResolutionEntity(
              resolutionType: 'split',
              payerRefundAmount: 25000,
              payeeReleaseAmount: 25000,
              reasoning: 'The amount is split between the parties.',
            ),
          ),
        ),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Resolution'), findsOneWidget);
      expect(find.text('Split between parties'), findsOneWidget);
      expect(find.textContaining('Refund to payer:'), findsOneWidget);
      expect(find.textContaining('Release to provider:'), findsOneWidget);
      expect(
        find.text('The amount is split between the parties.'),
        findsOneWidget,
      );
    });

    testWidgets('does not render a resolution card when none exists',
        (WidgetTester tester) async {
      final provider = providerWith(FakeDisputeRepository(detail: detail()));
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Resolution'), findsNothing);
    });

    testWidgets('shows the withdraw action while the case is open',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail(status: 'open')),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Withdraw dispute'), findsOneWidget);
    });

    testWidgets('hides the withdraw action when the case is not open',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail(status: 'resolved')),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Withdraw dispute'), findsNothing);
    });

    testWidgets('withdraw flow requires confirmation and updates state',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository(
        detail: detail(status: 'open'),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);
      await pumpDetail(tester, provider);

      await tester.tap(find.text('Withdraw dispute'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw dispute?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Withdraw'));
      await tester.pumpAndSettle();

      expect(repository.withdrawCallCount, 1);
      expect(find.text('Dispute withdrawn'), findsOneWidget); // snackbar
      expect(find.text('Withdrawn'), findsOneWidget); // status badge
    });

    testWidgets('withdraw cancelled keeps the case open',
        (WidgetTester tester) async {
      final repository = FakeDisputeRepository(detail: detail(status: 'open'));
      final provider = providerWith(repository);
      addTearDown(provider.dispose);
      await pumpDetail(tester, provider);

      await tester.tap(find.text('Withdraw dispute'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.withdrawCallCount, 0);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('renders the immutability and audit-awareness note',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail(status: 'resolved')),
      );
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(
        find.textContaining('evidence and resolutions cannot be edited'),
        findsOneWidget,
      );
      expect(
        find.textContaining('server-side audit trail'),
        findsOneWidget,
      );
    });

    testWidgets('Add evidence pushes the evidence-new route when can submit',
        (WidgetTester tester) async {
      final provider = providerWith(
        FakeDisputeRepository(detail: detail(status: 'open')),
      );
      addTearDown(provider.dispose);

      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.disputeDetail.replaceAll(':id', 'dispute-1'),
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.disputeDetail,
            builder: (_, _) => const DisputeDetailScreen(caseId: 'dispute-1'),
          ),
          GoRoute(
            path: RoutePaths.disputesEvidenceNew,
            builder: (_, _) => const Scaffold(
              body: Center(child: Text('evidence-screen')),
            ),
          ),
        ],
      );

      await pumpDetail(tester, provider, router: router);

      await tester.tap(find.text('Add evidence'));
      await tester.pumpAndSettle();

      expect(find.text('evidence-screen'), findsOneWidget);
    });
  });
}

extension DisputeCaseDetailTest on DisputeCaseDetail {
  DisputeCaseDetail withCase(DisputeCase case_) => DisputeCaseDetail(
        disputeCase: case_,
        evidence: evidence,
        resolution: resolution,
      );
}