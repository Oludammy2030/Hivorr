import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/service_dispute_contract_summary.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/providers/admin_dispute_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_dispute_repository.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/support/screens/admin_dispute_detail_screen.dart';
import 'package:hivorr/systems/support/screens/admin_dispute_queue_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

class _AdminReviewRepo implements AdminReviewRepository {
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

class _AdminDisputeRepo implements AdminDisputeRepository {
  int listCalls = 0;
  String? lastStatus;

  static const ServiceDisputeContractSummary summary =
      ServiceDisputeContractSummary(
        id: 'contract-1',
        status: 'disputed',
        escrowId: 'escrow-9',
        totalAmount: 20000,
        currencyCode: 'NGN',
        serviceListingId: 'listing-1',
        listingTitle: 'Fixture service offering',
      );

  @override
  Future<AdminDisputePage> listDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls++;
    lastStatus = status;
    return AdminDisputePage(
      items: <DisputeCase>[
        seedDisputeCaseEntity(
          id: 'dispute-1',
          escrowId: 'escrow-9',
          contractId: 'contract-1',
          status: 'open',
        ),
        seedDisputeCaseEntity(
          id: 'dispute-2',
          escrowId: '',
          contractId: 'contract-2',
          status: 'under_review',
        ),
      ],
      totalCount: 2,
    );
  }

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async =>
      seedDisputeDetailEntity(
        id: caseId,
        status: 'open',
        contractId: 'contract-1',
        contractSummary: summary,
      );
}

AdminReviewProvider adminGate() {
  final provider = AdminReviewProvider(repo: _AdminReviewRepo());
  addTearDown(provider.dispose);
  return provider;
}

Future<void> pumpAdmin(
  WidgetTester tester,
  Widget screen, {
  required AdminDisputeProvider disputes,
  AdminReviewProvider? gate,
}) async {
  await pumpApp(
    tester,
    screen,
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AdminDisputeProvider>.value(value: disputes),
      if (gate != null)
        ChangeNotifierProvider<AdminReviewProvider>.value(value: gate),
    ],
  );
  await tester.pumpAndSettle();
}

AdminDisputeProvider disputes() {
  final provider = AdminDisputeProvider(
    repository: _AdminDisputeRepo(),
  );
  addTearDown(provider.dispose);
  return provider;
}

void main() {
  group('AdminDisputeQueueScreen (R3)', () {
    testWidgets('fail-closed without an admin gate provider', (
      WidgetTester tester,
    ) async {
      final provider = disputes();

      await pumpApp(
        tester,
        const AdminDisputeQueueScreen(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminDisputeProvider>.value(
            value: provider,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin access required'), findsOneWidget);
    });

    testWidgets('renders rows with the server total', (
      WidgetTester tester,
    ) async {
      final gate = adminGate();
      await gate.checkAdmin();
      final provider = disputes();

      await pumpAdmin(
        tester,
        const AdminDisputeQueueScreen(),
        disputes: provider,
        gate: gate,
      );

      expect(find.text('Disputes'), findsOneWidget);
      expect(find.text('2 cases'), findsOneWidget);
      expect(find.text('Service quality'), findsWidgets);
    });

    testWidgets('filter chips re-query with the status', (
      WidgetTester tester,
    ) async {
      final gate = adminGate();
      await gate.checkAdmin();
      final repo = _AdminDisputeRepo();
      final provider = AdminDisputeProvider(repository: repo);
      addTearDown(provider.dispose);

      await pumpAdmin(
        tester,
        const AdminDisputeQueueScreen(),
        disputes: provider,
        gate: gate,
      );

      final Finder openChip = find.descendant(
        of: find.byType(HivorrChip),
        matching: find.text('Open'),
      );
      expect(openChip, findsOneWidget);
      await tester.tap(openChip);
      await tester.pumpAndSettle();

      expect(repo.lastStatus, 'open');
    });
  });

  group('AdminDisputeDetailScreen (R3)', () {
    testWidgets('renders contract card without participant actions', (
      WidgetTester tester,
    ) async {
      final gate = adminGate();
      await gate.checkAdmin();
      final provider = disputes();

      await pumpAdmin(
        tester,
        const AdminDisputeDetailScreen(caseId: 'dispute-1'),
        disputes: provider,
        gate: gate,
      );

      expect(find.text('Dispute case'), findsOneWidget);
      expect(find.text('Fixture service offering'), findsOneWidget);
      // Action-less admin card: no navigation affordances on this surface.
      expect(find.text('View contract'), findsNothing);
      expect(find.text('View escrow'), findsNothing);
      expect(find.textContaining('Read-only admin view'), findsOneWidget);
      // No participant affordances on the admin surface.
      expect(find.text('Withdraw dispute'), findsNothing);
      expect(find.text('Add evidence'), findsNothing);
    });

    testWidgets('fail-closed without an admin gate provider', (
      WidgetTester tester,
    ) async {
      final provider = disputes();

      await pumpApp(
        tester,
        const AdminDisputeDetailScreen(caseId: 'dispute-1'),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminDisputeProvider>.value(
            value: provider,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin access required'), findsOneWidget);
    });
  });
}
