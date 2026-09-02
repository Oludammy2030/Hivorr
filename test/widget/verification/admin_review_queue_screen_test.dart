import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/verification/screens/admin_review_queue_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_trade_verification.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<TradeVerificationProvider> pumpScreenWith(
    WidgetTester tester, {
    TradeVerificationRepository? repo,
    TradeReviewDecider? onDecide,
  }) async {
    final TradeVerificationProvider provider =
        TradeVerificationProvider(repo: repo ?? FakeTradeVerificationRepository());
    // Pre-refresh so the aggregate is non-null before the first frame.
    await provider.refreshStatus();
    await pumpApp(
      tester,
      AdminReviewQueueScreen(
        onDecide: onDecide,
        professionLabel: (String id) => 'Profession $id',
      ),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TradeVerificationProvider>.value(value: provider),
      ],
    );
    return provider;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('AdminReviewQueueScreen layout', () {
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      await tester.pump();
      expect(find.text('Review queue'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the empty state when the queue is clear',
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

      expect(find.text('Queue is clear'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('lists pending professions with approve + reject actions',
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

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('initial load', () {
    testWidgets('shows the loading state until the queue is fetched',
        (WidgetTester tester) async {
      final TradeVerificationProvider provider =
          TradeVerificationProvider(repo: FakeTradeVerificationRepository());
      await pumpApp(
        tester,
        AdminReviewQueueScreen(
          professionLabel: (String id) => 'Profession $id',
        ),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TradeVerificationProvider>.value(value: provider),
        ],
      );

      expect(find.byType(HivorrLoadingState), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('fetches the queue on first build when status is null',
        (WidgetTester tester) async {
      final FakeTradeVerificationRepository repo =
          FakeTradeVerificationRepository(
            status: tradeStatusEntity(
              statuses: <String, String>{'p1': 'pending'},
            ),
          );
      final TradeVerificationProvider provider =
          TradeVerificationProvider(repo: repo);
      await pumpApp(
        tester,
        AdminReviewQueueScreen(
          professionLabel: (String id) => 'Profession $id',
        ),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<TradeVerificationProvider>.value(value: provider),
        ],
      );

      // The screen — not the caller — must trigger the initial load directly
      // into a completed aggregate (the loading test above pins the interim
      // state).
      await tester.pump();
      await tester.pump();

      expect(repo.statusCallCount, 1);
      expect(find.byType(HivorrLoadingState), findsNothing);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('decisions', () {
    testWidgets('approve calls the injected decider with notes',
        (WidgetTester tester) async {
      String? approvedId;
      bool? approvedFlag;
      String? approvedNotes;
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
        onDecide: ({
          required String professionId,
          required bool approved,
          required String notes,
        }) async {
          approvedId = professionId;
          approvedFlag = approved;
          approvedNotes = notes;
        },
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'Clear evidence attached',
      );
      await tester.tap(find.text('Approve'));
      await tester.pump();

      expect(approvedId, 'p1');
      expect(approvedFlag, isTrue);
      expect(approvedNotes, 'Clear evidence attached');
      await unmount(tester);
    });

    testWidgets('reject calls the injected decider with approved=false',
        (WidgetTester tester) async {
      bool? lastApproved;
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
        onDecide: ({
          required String professionId,
          required bool approved,
          required String notes,
        }) async {
          lastApproved = approved;
        },
      );
      await tester.pump();

      await tester.tap(find.text('Reject'));
      await tester.pump();

      expect(lastApproved, isFalse);
      await unmount(tester);
    });

    testWidgets('shows a positive feedback line after approving',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
        onDecide: asyncFree,
      );
      await tester.pump();

      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Approved Profession p1'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('surfaces a decider failure to the reviewer',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
        onDecide: (
          {
          required String professionId,
          required bool approved,
          required String notes,
        }) async {
          throw StateError('service-role unavailable');
        },
      );
      await tester.pump();

      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Decision failed: Bad state: service-role unavailable'),
          findsOneWidget);
      await unmount(tester);
    });

    testWidgets('decisions are disabled when no decider is injected',
        (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: <String, String>{'p1': 'pending'},
          ),
        ),
        onDecide: null,
      );
      await tester.pump();

      final Finder approve = find.widgetWithText(HivorrButton, 'Approve');
      expect(tester.widget<HivorrButton>(approve).onPressed, isNull);
      await unmount(tester);
    });
  });
}

/// No-op decider for feedback-line assertions.
Future<void> asyncFree({
  required String professionId,
  required bool approved,
  required String notes,
}) async {}
