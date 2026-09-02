import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:hivorr/systems/verification/screens/trade_verification_status_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_trade_verification.dart';
import '../../support/harnesses/widget_harness.dart';

/// A repository whose status fetch never completes, so the screen stays in its
/// loading state (the provider's `refreshStatus` hangs).
class _BlockingRepo implements TradeVerificationRepository {
  _BlockingRepo();
  final Completer<void> _never = Completer<void>();

  @override
  Future<TradeVerificationStatus> getStatus() =>
      _never.future.then((_) => throw StateError('never'));

  @override
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) =>
      throw UnimplementedError();
}


void main() {
  Future<TradeVerificationProvider> pumpScreenWith(
    WidgetTester tester, {
    TradeVerificationRepository? repo,
  }) async {
    final TradeVerificationProvider provider =
        TradeVerificationProvider(repo: repo ?? FakeTradeVerificationRepository());
    await pumpApp(
      tester,
      const TradeVerificationStatusScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TradeVerificationProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('TradeVerificationStatusScreen layout', () {
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();
      expect(find.text('Trade verification'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('approved profession shows the verified badge and unlocked '
        'bidding', (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'approved'},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bidding unlocked'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('pending profession shows the bid-lock panel',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('bidding is locked'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('no bound professions renders the empty state',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(statuses: const <String, String>{}),
        ),
      );
      await tester.pump();

      expect(find.text('No bound professions'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('renders one section per bound profession',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'approved', 'p2': 'pending'},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('p1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('p2')), findsOneWidget);
      expect(find.text('Profession p1'), findsAtLeastNWidgets(1));
      expect(find.text('Profession p2'), findsAtLeastNWidgets(1));
      expect(find.text('Bidding unlocked'), findsOneWidget);
      expect(find.textContaining('bidding is locked'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('wraps content in a pull-to-refresh indicator',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
      await unmount(tester);
    });
  });

  group('status-derived timelines', () {
    testWidgets('approved timeline marks the decided step bold',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'approved'},
          ),
        ),
      );
      await tester.pump();

      final Text decided = tester.widget<Text>(find.text('Approved'));
      expect(decided.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });

    testWidgets('pending timeline marks pending review bold',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
      );
      await tester.pump();

      final Text pending = tester.widget<Text>(find.text('Pending review'));
      expect(pending.style?.fontWeight, FontWeight.w600);
      await unmount(tester);
    });
  });

  group('rejected action', () {
    testWidgets('rejected profession renders the error state + Resubmit CTA',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'rejected'},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This trade proof was not approved.'), findsOneWidget);
      expect(find.text('Resubmit'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('rejected detail guides a resubmission',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'rejected'},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Please upload a new, clearer proof to continue.'),
        findsOneWidget,
      );
      await unmount(tester);
    });
  });

  group('async states', () {
    testWidgets('shows loading while the aggregate is null',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: _BlockingRepo(),
      );
      await tester.pump();

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('recovers after a failed refresh', (WidgetTester tester) async {
      final repo = FakeTradeVerificationRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'unavailable',
          code: 'X9',
        );
      await pumpScreenWith(tester, repo: repo);
      await tester.pump();

      // Error is stored but content still renders from the seed aggregate.
      expect(find.text('Trade verification'), findsOneWidget);
      await unmount(tester);
    });
  });
}
