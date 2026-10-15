import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/providers/admin_dispute_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/repositories/admin_dispute_repository.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/systems/support/screens/admin_dispute_detail_screen.dart';
import 'package:hivorr/systems/support/screens/admin_dispute_queue_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_detail_screen.dart';
import 'package:hivorr/systems/support/screens/dispute_filing_screen.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/support/fake_dispute_repository.dart';

class _AdminGateRepo implements AdminReviewRepository {
  @override
  Future<bool> checkAdmin() async => true;

  @override
  int? get lastTotalCount => null;

  @override
  Future<List<AdminReviewQueueEntry>> getReviewQueue({
    String? submissionType,
    int limit = 50,
    int offset = 0,
    String? search,
    String? professionId,
    String? sort,
  }) => throw UnimplementedError();

  @override
  Future<void> startReview(String submissionId) => throw UnimplementedError();

  @override
  Future<void> approveSubmission(String submissionId, {String notes = ''}) =>
      throw UnimplementedError();

  @override
  Future<void> rejectSubmission(
    String submissionId, {
    String notes = '',
    bool requiresResubmission = false,
  }) => throw UnimplementedError();

  @override
  Future<List<AdminReviewAuditEntry>> getAuditTrail(String submissionId) =>
      throw UnimplementedError();

  @override
  Future<AdminReviewProfile> getReviewProfile(String submissionId) =>
      throw UnimplementedError();

  @override
  Future<String> createDocumentSignedUrl(
    String credentialId, {
    int expiresIn = 60,
  }) => throw UnimplementedError();

  @override
  Future<AdminReviewMetrics> getReviewMetrics({
    int periodDays = 30,
    String? submissionType,
  }) => throw UnimplementedError();
}

class _AdminDisputes implements AdminDisputeRepository {
  @override
  Future<AdminDisputePage> listDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => const AdminDisputePage(items: [], totalCount: 0);

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async =>
      seedDisputeDetailEntity(id: caseId);
}

Future<void> pumpRoutes(
  WidgetTester tester,
  String location, {
  required List<SingleChildWidget> providers,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.disputesFileForContractRoute,
        name: RouteNames.disputesFileForContract,
        builder: (BuildContext context, GoRouterState state) =>
            DisputeFilingScreen(
              contractId: state.pathParameters['contractId'] ?? '',
            ),
      ),
      GoRoute(
        path: RoutePaths.disputeDetail,
        name: RouteNames.disputeDetail,
        builder: (BuildContext context, GoRouterState state) =>
            DisputeDetailScreen(caseId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.adminDisputes,
        name: RouteNames.adminDisputes,
        builder: (BuildContext context, GoRouterState state) =>
            const AdminDisputeQueueScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminDisputeDetail,
        name: RouteNames.adminDisputeDetail,
        builder: (BuildContext context, GoRouterState state) =>
            AdminDisputeDetailScreen(
              caseId: state.pathParameters['caseId'] ?? '',
            ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('route builders produce the documented deep-link paths', () {
    expect(
      RoutePaths.disputesFileForContract('contract-1'),
      '/support/disputes/file-by-contract/contract-1',
    );
    expect(
      RoutePaths.disputesFileForContract('a/b'),
      '/support/disputes/file-by-contract/${Uri.encodeComponent('a/b')}',
    );
    expect(RoutePaths.adminDisputes, '/admin/disputes');
    expect(RoutePaths.adminDisputeDetail, '/admin/disputes/:caseId');
    expect(RouteNames.disputesFileForContract, 'disputes-file-for-contract');
  });

  group('dispute deep links land on the right screens', () {
    testWidgets('file-by-contract renders contract-mode filing', (
      WidgetTester tester,
    ) async {
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
      );
      addTearDown(provider.dispose);

      await pumpRoutes(
        tester,
        '/support/disputes/file-by-contract/contract-9',
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<DisputeProvider>.value(value: provider),
        ],
      );

      expect(find.widgetWithText(AppBar, 'File dispute'), findsOneWidget);
      expect(find.textContaining('Filing freezes contract'), findsOneWidget);
    });

    testWidgets('dispute detail renders the case screen', (
      WidgetTester tester,
    ) async {
      final provider = DisputeProvider(
        service: DisputeService(
          repository: FakeDisputeRepository(
            detail: seedDisputeDetailEntity(id: 'dispute-7'),
          ),
        ),
      );
      addTearDown(provider.dispose);

      await pumpRoutes(
        tester,
        '/support/disputes/dispute-7',
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<DisputeProvider>.value(value: provider),
        ],
      );

      expect(find.widgetWithText(AppBar, 'Dispute'), findsOneWidget);
    });

    testWidgets('admin queue renders inside the admin shell pattern', (
      WidgetTester tester,
    ) async {
      final gate = AdminReviewProvider(repo: _AdminGateRepo());
      await gate.checkAdmin();
      addTearDown(gate.dispose);
      final disputes = AdminDisputeProvider(repository: _AdminDisputes());
      addTearDown(disputes.dispose);

      await pumpRoutes(
        tester,
        '/admin/disputes',
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminReviewProvider>.value(value: gate),
          ChangeNotifierProvider<AdminDisputeProvider>.value(
            value: disputes,
          ),
        ],
      );

      expect(find.widgetWithText(AppBar, 'Disputes'), findsOneWidget);
    });

    testWidgets('admin detail renders the case screen', (
      WidgetTester tester,
    ) async {
      final gate = AdminReviewProvider(repo: _AdminGateRepo());
      await gate.checkAdmin();
      addTearDown(gate.dispose);
      final disputes = AdminDisputeProvider(repository: _AdminDisputes());
      addTearDown(disputes.dispose);

      await pumpRoutes(
        tester,
        '/admin/disputes/dispute-7',
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminReviewProvider>.value(value: gate),
          ChangeNotifierProvider<AdminDisputeProvider>.value(
            value: disputes,
          ),
        ],
      );

      expect(find.widgetWithText(AppBar, 'Dispute case'), findsOneWidget);
    });
  });
}
