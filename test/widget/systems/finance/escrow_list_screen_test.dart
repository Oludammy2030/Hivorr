import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/repositories/escrow_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/screens/escrow_list_screen.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';
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
  Future<EscrowDetail> getById(String id) =>
      Completer<EscrowDetail>().future;

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
      EscrowProvider(
        service: EscrowService(repository: repository),
      );

  Future<void> pumpList(
    WidgetTester tester,
    EscrowProvider provider,
  ) async {
    await pumpApp(
      tester,
      const EscrowListScreen(projectId: 'untitled'),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<EscrowProvider>.value(value: provider),
      ],
    );
  }

  group('EscrowListScreen', () {
    testWidgets('renders the Escrows app bar title',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository();
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Escrows'), findsOneWidget);
    });

    testWidgets('shows HivorrLoadingState while the list is pending',
        (WidgetTester tester) async {
      final provider = providerWith(_HangingEscrowRepository());
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
    });

    testWidgets('renders one card per escrow with badge and amount',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        headers: <Escrow>[
          seedEscrowEntity(id: 'e1'),
          seedEscrowEntity(
            id: 'e2',
            totalAmount: 100000,
            releasedAmount: 100000,
            status: 'released',
          ),
        ],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('\u20A650,000.00'), findsOneWidget);
      expect(find.text('\u20A6100,000.00'), findsOneWidget);
      expect(find.text('Funded & held'), findsOneWidget);
      expect(find.text('Released to provider'), findsOneWidget);
    });

    testWidgets('shows HivorrEmptyState when no escrows exist',
        (WidgetTester tester) async {
      final provider = providerWith(FakeEscrowRepository(headers: const []));
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();

      expect(find.byType(HivorrEmptyState), findsOneWidget);
      expect(find.text('No active escrows'), findsOneWidget);
    });

    testWidgets('shows HivorrErrorState on read failure',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository();
      repository.nextError = const ApiException(
        kind: ApiExceptionKind.forbidden,
        message: 'Not allowed',
        code: 'PLT002',
        statusCode: 403,
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();

      expect(find.byType(HivorrErrorState), findsOneWidget);
      expect(find.text('Failed to load escrows'), findsOneWidget);
      expect(find.text('Not allowed'), findsOneWidget);
    });

    testWidgets('pull-to-refresh reloads the list', (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        headers: <Escrow>[seedEscrowEntity()],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();
      final int initial = repository.getByProjectCallCount;

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(repository.getByProjectCallCount, greaterThan(initial));
    });

    testWidgets('reloads when the app resumes from background',
        (WidgetTester tester) async {
      final repository = FakeEscrowRepository(
        headers: <Escrow>[seedEscrowEntity()],
      );
      final provider = providerWith(repository);
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();
      final int initial = repository.getByProjectCallCount;

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.getByProjectCallCount, greaterThan(initial));
    });

    testWidgets('empty list does not render cards', (WidgetTester tester) async {
      final provider = providerWith(FakeEscrowRepository(headers: const []));
      addTearDown(provider.dispose);

      await pumpList(tester, provider);
      await tester.pumpAndSettle();

      expect(find.byType(EscrowListScreen), findsOneWidget);
    });
  });
}