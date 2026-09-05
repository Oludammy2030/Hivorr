import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/screens/escrow_detail_screen.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
import 'package:hivorr/systems/finance/widgets/escrow_dispute_banner.dart';
import 'package:hivorr/systems/finance/widgets/escrow_write_cta_panel.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/finance/fake_escrow_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

class _HangingEscrowRepository implements EscrowRepository {
  @override
  bool get writeAvailable => false;

  @override
  Future<List<Escrow>> getByProject({
    required String projectId,
    required List<String> escrowIds,
  }) =>
      Completer<List<Escrow>>().future;

  @override
  Future<EscrowDetail> getById(String id) => Completer<EscrowDetail>().future;

  @override
  Future<EscrowDetail> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) =>
      throw UnimplementedError();

  @override
  Future<EscrowDetail> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) =>
      throw UnimplementedError();

  @override
  Future<EscrowDetail> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) =>
      throw UnimplementedError();

  @override
  Future<EscrowDetail> releaseFinal({required String escrowId}) =>
      throw UnimplementedError();

  @override
  Future<EscrowDetail> refundEscrow({
    required String escrowId,
    required String reason,
  }) =>
      throw UnimplementedError();
}

void main() {
  EscrowProvider providerWith(EscrowRepository repository) =>
      EscrowProvider(service: EscrowService(repository: repository));

  Future<void> pumpDetail(
    WidgetTester tester,
    EscrowProvider provider, {
    VoidCallback? onViewDispute,
  }) async {
    await pumpApp(
      tester,
      EscrowDetailScreen(
        escrowId: 'escrow-1',
        onViewDispute: onViewDispute,
      ),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<EscrowProvider>.value(value: provider),
      ],
    );
  }

  /// Renders the screen at a tall 800×1400 logical viewport so every section
  /// (header, milestones, ledger, action panel) is inflated by the ListView.
  Future<void> pumpTallDetail(
    WidgetTester tester,
    EscrowProvider provider, {
    VoidCallback? onViewDispute,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.devicePixelRatio = 3.0;
    });
    await pumpDetail(tester, provider, onViewDispute: onViewDispute);
  }

  EscrowDetail seedDetail() => seedEscrowDetailEntity(
        id: 'escrow-1',
        status: 'funded',
        milestones: <EscrowMilestone>[
          seedMilestoneEntity(
            id: 'ms-1',
            milestoneNumber: 1,
            title: 'Design sign-off',
            amount: 30000,
            status: 'completed',
          ),
          seedMilestoneEntity(
            id: 'ms-2',
            milestoneNumber: 2,
            title: 'Delivery',
            amount: 20000,
            status: 'pending',
          ),
        ],
        transactions: <EscrowTransaction>[
          seedTransactionEntity(amount: 20000),
        ],
      );

  group('EscrowDetailScreen', () {
    testWidgets('header shows formatted amount, badge and masked reference',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('\u20A650,000.00'), findsOneWidget);
      expect(find.text('Funded & held'), findsOneWidget);
      expect(find.text('Ref ***0123'), findsOneWidget);
      expect(find.text('ORD-2026-000123'), findsNothing);
    });

    testWidgets('header shows held and released amounts',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Held: \u20A650,000.00'), findsOneWidget);
      expect(find.text('Released: \u20A60.00'), findsOneWidget);
    });

    testWidgets('renders milestone rows with status chips',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(find.byType(MilestoneListCard), findsOneWidget);
      expect(find.text('1. Design sign-off'), findsOneWidget);
      expect(find.text('2. Delivery'), findsOneWidget);
      expect(find.text('Completed — awaiting release'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('renders the read-only ledger when transactions exist',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Ledger'), findsOneWidget);
      expect(find.text('release'), findsOneWidget);
      expect(find.text('\u20A620,000.00'), findsNWidgets(2));
    });

    testWidgets('shows an empty ledger hint when the migration returns none',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(
        find.text('Ledger entries appear once funds move within this escrow.'),
        findsOneWidget,
      );
    });

    testWidgets('shows HivorrLoadingState while the detail is pending',
        (WidgetTester tester) async {
      final provider = providerWith(_HangingEscrowRepository());
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
    });

    testWidgets('shows HivorrErrorState on load failure',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository();
      repository.nextError = const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Escrow not found',
        code: 'PLT004',
        statusCode: 404,
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(find.text('Failed to load escrow'), findsOneWidget);
    });

    testWidgets('renders the dispute banner and routes "View dispute"',
        (WidgetTester tester) async {
      var viewed = false;
      final repository = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(
          id: 'escrow-1',
          status: 'disputed',
        ),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider, onViewDispute: () => viewed = true);
      await tester.pumpAndSettle();

      expect(find.byType(EscrowDisputeBanner), findsOneWidget);
      expect(
        find.text('In dispute — all actions frozen until resolved'),
        findsOneWidget,
      );
      await tester.tap(find.text('View dispute'));
      expect(viewed, isTrue);
    });

    testWidgets('disputed escrow disables every action even when writable',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedEscrowDetailEntity(
          id: 'escrow-1',
          status: 'disputed',
          milestones: <EscrowMilestone>[
            seedMilestoneEntity(status: 'completed'),
            seedMilestoneEntity(
              id: 'ms-2',
              status: 'pending',
              amount: 20000,
            ),
          ],
        ),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpTallDetail(tester, provider);
      await tester.pumpAndSettle();

      final List<HivorrButton> buttons =
          tester.widgetList<HivorrButton>(find.byType(HivorrButton)).toList();
      expect(buttons, hasLength(4));
      expect(
        buttons.map((HivorrButton b) => b.onPressed),
        everyElement(isNull),
      );
    });

    testWidgets('write seam off shows support guidance, never a dead-end button',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: false,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);
      await tester.pumpAndSettle();

      expect(find.byType(EscrowWriteCtaPanel), findsOneWidget);
      expect(
        find.text('Escrow actions are handled by our support team'),
        findsOneWidget,
      );
      expect(find.byType(HivorrButton), findsNothing);
      expect(find.text('Complete milestone'), findsNothing);
    });

    testWidgets('release milestone action drives the provider write path',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpTallDetail(tester, provider);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Release milestone'));
      await tester.pumpAndSettle();

      expect(repository.releaseMilestoneCallCount, 1);
      expect(repository.lastMilestoneId, 'ms-1');
    });

    testWidgets('release final action drives the provider write path',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        writeAvailable: true,
        detail: seedDetail(),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpTallDetail(tester, provider);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Release final payment'));
      await tester.pumpAndSettle();

      expect(repository.releaseFinalCallCount, 1);
    });

    testWidgets('falls back to "Escrow not found" before any selection loads',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        detail: seedEscrowDetailEntity(id: 'escrow-1'),
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpDetail(tester, provider);

      expect(find.text('Escrow not found'), findsOneWidget);
    });
  });
}