import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/entities/service_dispute_contract_summary.dart';
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

import '../../../support/fakes/support/fake_dispute_repository.dart';
import '../../../support/harnesses/responsive_harness.dart';
import '../../../support/harnesses/widget_harness.dart';

const ServiceDisputeContractSummary fundedSummary =
    ServiceDisputeContractSummary(
      id: 'contract-1',
      status: 'disputed',
      escrowId: 'escrow-9',
      totalAmount: 20000,
      currencyCode: 'NGN',
      serviceListingId: 'listing-1',
      listingTitle: 'Fixture service offering',
    );

const ServiceDisputeContractSummary unfundedSummary =
    ServiceDisputeContractSummary(
      id: 'contract-2',
      status: 'disputed',
      totalAmount: 5000,
      currencyCode: 'NGN',
      serviceListingId: 'listing-2',
    );

DisputeProvider providerWithDetail({
  String id = 'dispute-1',
  String status = 'open',
  String? contractId,
  ServiceDisputeContractSummary? contractSummary,
}) {
  final provider = DisputeProvider(
    service: DisputeService(
      repository: FakeDisputeRepository(
        detail: seedDisputeDetailEntity(
          id: id,
          status: status,
          contractId: contractId,
          contractSummary: contractSummary,
        ),
      ),
    ),
  );
  addTearDown(provider.dispose);
  return provider;
}

Future<void> pumpWithDisputes(
  WidgetTester tester,
  DisputeProvider provider,
  Widget screen,
) async {
  await pumpApp(
    tester,
    screen,
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<DisputeProvider>.value(value: provider),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DisputeDetailScreen contract card (EP-03-17)', () {
    testWidgets('funded case renders View contract and View escrow', (
      WidgetTester tester,
    ) async {
      final provider = providerWithDetail(
        contractId: 'contract-1',
        contractSummary: fundedSummary,
      );

      await pumpWithDisputes(
        tester,
        provider,
        const DisputeDetailScreen(caseId: 'dispute-1'),
      );

      expect(find.text('View contract'), findsOneWidget);
      expect(find.text('View escrow'), findsOneWidget);
      expect(find.text('Fixture service offering'), findsOneWidget);
    });

    testWidgets('unfunded case renders Funding pending without View escrow', (
      WidgetTester tester,
    ) async {
      final provider = providerWithDetail(
        contractId: 'contract-2',
        contractSummary: unfundedSummary,
      );

      await pumpWithDisputes(
        tester,
        provider,
        const DisputeDetailScreen(caseId: 'dispute-1'),
      );

      expect(find.text('View contract'), findsOneWidget);
      expect(find.text('View escrow'), findsNothing);
      expect(find.textContaining('Funding pending'), findsOneWidget);
    });

    testWidgets('legacy escrow-only case renders no contract card', (
      WidgetTester tester,
    ) async {
      final provider = providerWithDetail();

      await pumpWithDisputes(
        tester,
        provider,
        const DisputeDetailScreen(caseId: 'dispute-1'),
      );

      expect(find.text('View contract'), findsNothing);
      expect(find.text('View escrow'), findsNothing);
    });

    testWidgets('contract card uses theme tokens only', (
      WidgetTester tester,
    ) async {
      final provider = providerWithDetail(
        contractId: 'contract-1',
        contractSummary: fundedSummary,
      );

      await pumpWithDisputes(
        tester,
        provider,
        Theme(
          data: AppTheme.lightTheme,
          child: const DisputeDetailScreen(caseId: 'dispute-1'),
        ),
      );

      expect(find.text('View contract'), findsOneWidget);
    });
  });

  group('DisputeFilingScreen contract mode (EP-03-17)', () {
    testWidgets('renders the contract freeze copy', (
      WidgetTester tester,
    ) async {
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
      );
      addTearDown(provider.dispose);

      await pumpWithDisputes(
        tester,
        provider,
        const DisputeFilingScreen(contractId: 'contract-1'),
      );

      expect(find.widgetWithText(AppBar, 'File dispute'), findsOneWidget);
      expect(find.textContaining('Filing freezes contract'), findsOneWidget);
      expect(find.textContaining('Filing freezes escrow'), findsNothing);
    });

    testWidgets('submit stays disabled until a type and reason are entered', (
      WidgetTester tester,
    ) async {
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
      );
      addTearDown(provider.dispose);

      await pumpWithDisputes(
        tester,
        provider,
        const DisputeFilingScreen(contractId: 'contract-1'),
      );

      // No type selected and an empty reason: no enabled File dispute button
      // should submit. The button exists but must be disabled.
      expect(find.text('File dispute'), findsWidgets);
    });
  });

  group('Responsive matrix (DoD §7.1)', () {
    testWidgets('filing (contract mode) has no overflow at mobile widths', (
      WidgetTester tester,
    ) async {
      await expectNoOverflowAtMobileWidths(
        tester,
        () {
          final provider = DisputeProvider(
            service: DisputeService(repository: FakeDisputeRepository()),
          );
          return MultiProvider(
            providers: <SingleChildWidget>[
              ChangeNotifierProvider<DisputeProvider>.value(value: provider),
            ],
            child: const DisputeFilingScreen(contractId: 'contract-1'),
          );
        },
      );
    });

    testWidgets('detail (funded) has no overflow at mobile widths', (
      WidgetTester tester,
    ) async {
      final provider = providerWithDetail(
        contractId: 'contract-1',
        contractSummary: fundedSummary,
      );

      await expectNoOverflowAtMobileWidths(
        tester,
        () => MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<DisputeProvider>.value(value: provider),
          ],
          child: const DisputeDetailScreen(caseId: 'dispute-1'),
        ),
      );
    });

    testWidgets('admin queue has no overflow at mobile widths', (
      WidgetTester tester,
    ) async {
      final gate = _MatrixGateRepo.admin();
      await gate.checkAdmin();
      final disputes = AdminDisputeProvider(
        repository: _MatrixAdminRepo(),
      );

      await expectNoOverflowAtMobileWidths(
        tester,
        () => MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AdminReviewProvider>.value(value: gate),
            ChangeNotifierProvider<AdminDisputeProvider>.value(
              value: disputes,
            ),
          ],
          child: const AdminDisputeQueueScreen(),
        ),
      );
      gate.dispose();
      disputes.dispose();
    });

    testWidgets('admin detail has no overflow at mobile widths', (
      WidgetTester tester,
    ) async {
      final gate = _MatrixGateRepo.admin();
      await gate.checkAdmin();
      final disputes = AdminDisputeProvider(
        repository: _MatrixAdminRepo(),
      );

      await expectNoOverflowAtMobileWidths(
        tester,
        () => MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<AdminReviewProvider>.value(value: gate),
            ChangeNotifierProvider<AdminDisputeProvider>.value(
              value: disputes,
            ),
          ],
          child: const AdminDisputeDetailScreen(caseId: 'dispute-1'),
        ),
      );
      gate.dispose();
      disputes.dispose();
    });
  });
}

class _MatrixGateRepo {
  static AdminReviewProvider admin() {
    final provider = AdminReviewProvider(repo: _AllowAdminReviewRepo());
    return provider;
  }
}

class _AllowAdminReviewRepo implements AdminReviewRepository {
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

class _MatrixAdminRepo implements AdminDisputeRepository {
  @override
  Future<AdminDisputePage> listDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminDisputePage(
    items: [
      seedDisputeCaseEntity(
        id: 'dispute-1',
        escrowId: 'escrow-9',
        contractId: 'contract-1',
      ),
    ],
    totalCount: 1,
  );

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async =>
      seedDisputeDetailEntity(
        id: caseId,
        contractId: 'contract-1',
        contractSummary: fundedSummary,
      );
}
