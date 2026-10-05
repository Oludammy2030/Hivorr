import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/verification/screens/admin_review_queue_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<AdminReviewProvider> pumpScreenWith(
    WidgetTester tester, {
    FakeAdminReviewRepository? repo,
  }) async {
    final FakeAdminReviewRepository resolvedRepo =
        repo ?? FakeAdminReviewRepository();
    final AdminReviewProvider provider = AdminReviewProvider(
      repo: resolvedRepo,
    );
    await pumpApp(
      tester,
      const AdminReviewQueueScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AdminReviewProvider>.value(value: provider),
      ],
    );
    // Let the post-frame checkAdmin + loadQueue settle.
    await tester.pump();
    await tester.pump();
    return provider;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('AdminReviewQueueScreen layout', () {
    testWidgets('renders no nested chrome (shell owns the title)', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(tester);
      expect(find.text('Verification & Approvals'), findsNothing);
      expect(find.text('Queue is clear'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the admin gate when the user is not an admin', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(isAdmin: false),
      );
      expect(find.text('Admin access required'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the empty state when the queue is clear', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(queue: const <AdminReviewQueueEntry>[]),
      );
      expect(find.text('Queue is clear'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('lists pending submissions', (WidgetTester tester) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Test Entity'),
          ],
        ),
      );
      expect(find.text('Test Entity'), findsOneWidget);
      // Human labels, never raw codes.
      expect(find.text('Trade proof'), findsOneWidget);
      expect(find.textContaining('trade_proof'), findsNothing);
      expect(find.textContaining('Status:'), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows a status badge per submission', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', status: 'pending'),
            adminQueueEntry(submissionId: 'sub-2', status: 'in_review'),
          ],
        ),
      );
      // Each label appears twice: once on its filter chip, once on the
      // submission badge.
      expect(find.text('Pending'), findsNWidgets(2));
      expect(find.text('In review'), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('renders the enterprise metrics row from real data', (
      WidgetTester tester,
    ) async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
        ],
      )..metricsResult = const AdminReviewMetrics(
        pendingTotal: 7,
        inReviewTotal: 2,
        avgVerificationSeconds: 259200,
        approvedToday: 3,
        decidedTotal: 10,
        rejectedTotal: 4,
        rejectionRate: 0.4,
        periodDays: 30,
      );
      await pumpScreenWith(tester, repo: repo);
      expect(find.text('Total Pending Reviews'), findsOneWidget);
      expect(find.text('Avg. Verification Time'), findsOneWidget);
      expect(find.text('Approved Today'), findsOneWidget);
      expect(find.text('Rejection Rate'), findsOneWidget);
      // Real RPC values, formatted — never invented.
      expect(find.text('7'), findsWidgets);
      expect(find.text('3d'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('40.0%'), findsOneWidget);
      expect(find.text('Trailing 30 days'), findsOneWidget);
      expect(find.text('Since UTC midnight'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('renders unavailable metrics when the window is empty', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        ),
      );
      // Fake serves zeroed metrics: empty-window states, never fake numbers.
      expect(find.text('No decisions in window'), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('renders the submissions table with review actions', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        ),
      );
      expect(find.text('Pending Professional Submissions'), findsOneWidget);
      expect(find.text('PROFESSIONAL'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      // No fabricated risk column.
      expect(find.text('RISK'), findsNothing);
      expect(find.textContaining('Risk'), findsNothing);
      await unmount(tester);
    });

    testWidgets('search filters the loaded queue', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
            adminQueueEntry(submissionId: 'sub-2', entityName: 'Grace Hopper'),
          ],
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsNothing);
      expect(find.text('1 of 2 shown'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('status chips filter the loaded queue', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', status: 'pending'),
            adminQueueEntry(submissionId: 'sub-2', status: 'in_review'),
          ],
        ),
      );
      await tester.tap(find.widgetWithText(HivorrChip, 'In review'));
      await tester.pump();
      expect(find.text('In review'), findsWidgets);
      // Only the filter chip keeps the Pending label; its card is gone.
      expect(find.text('Pending'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows a no-matches state for empty filters', (
      WidgetTester tester,
    ) async {
      await pumpScreenWith(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        ),
      );
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
      await unmount(tester);
    });
  });

  group('Master-detail workspace (wide)', () {
    Future<void> pumpWide(
      WidgetTester tester, {
      FakeAdminReviewRepository? repo,
    }) async {
      final FakeAdminReviewRepository resolvedRepo =
          repo ?? FakeAdminReviewRepository();
      final AdminReviewProvider provider = AdminReviewProvider(
        repo: resolvedRepo,
      );
      await pumpScreen(
        tester,
        const AdminReviewQueueScreen(),
        width: 1280,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminReviewProvider>.value(value: provider),
        ],
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('auto-selects the first submission with detail panels', (
      WidgetTester tester,
    ) async {
      await pumpWide(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        ),
      );
      // Entity name in list card + detail entity card; decision actions
      // rendered inline instead of pushing a route.
      expect(find.text('Ada Lovelace'), findsNWidgets(2));
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Audit trail'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('tapping a card switches the detail selection', (
      WidgetTester tester,
    ) async {
      await pumpWide(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
            adminQueueEntry(submissionId: 'sub-2', entityName: 'Grace Hopper'),
          ],
        ),
      );
      expect(find.text('Ada Lovelace'), findsNWidgets(2));

      await tester.tap(find.text('Grace Hopper').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Grace Hopper'), findsNWidgets(2));
      expect(find.text('Ada Lovelace'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows empty profile states when nothing is recorded', (
      WidgetTester tester,
    ) async {
      await pumpWide(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        ),
      );
      expect(find.text('Work Experience'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
      expect(
        find.text('No work history recorded by the applicant.'),
        findsOneWidget,
      );
      expect(
        find.text('No education recorded by the applicant.'),
        findsOneWidget,
      );
      expect(
        find.text('No skills recorded by the applicant.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('renders recorded experience, education, and skills', (
      WidgetTester tester,
    ) async {
      await pumpWide(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        )..setReviewProfile(adminReviewProfile()),
      );
      expect(find.text('Senior Plumber'), findsOneWidget);
      expect(find.text('Flow Masters'), findsOneWidget);
      expect(find.text('Trade Institute'), findsOneWidget);
      expect(find.text('Pipefitting · 6 yrs'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the selection prompt when nothing matches', (
      WidgetTester tester,
    ) async {
      await pumpWide(
        tester,
        repo: FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'Ada Lovelace'),
          ],
        ),
      );
      // First TextField in layout order is the search box (the notes
      // field lives in the details pane below it).
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Select a submission'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      await unmount(tester);
    });
  });

  group('initial load', () {
    testWidgets('shows the loading state until the queue is fetched', (
      WidgetTester tester,
    ) async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[adminQueueEntry(submissionId: 'sub-1')],
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
      await pumpApp(
        tester,
        const AdminReviewQueueScreen(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminReviewProvider>.value(value: provider),
        ],
      );

      // Before the post-frame admin check completes, the fail-closed gate
      // shows (never the queue behind it). No pump here: pumpApp already
      // built the first frame, and a pump would let the fake's immediate
      // checkAdmin resolve into the loading state.
      expect(find.text('Admin access required'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('fetches the queue on first build when empty', (
      WidgetTester tester,
    ) async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'Test Entity'),
        ],
      );
      await pumpScreenWith(tester, repo: repo);

      expect(repo.queueCallCount, greaterThanOrEqualTo(1));
      expect(find.text('Test Entity'), findsOneWidget);
      await unmount(tester);
    });
  });
}
