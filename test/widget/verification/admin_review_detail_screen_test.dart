import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/systems/verification/screens/admin_review_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  Future<FakeAdminReviewRepository> pumpDetail(
    WidgetTester tester, {
    List<AdminReviewQueueEntry>? queue,
  }) async {
    final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
      isAdmin: true,
      queue:
          queue ??
          <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1'),
          ],
    );
    final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
    // The detail screen resolves its entry from the loaded queue (the queue
    // screen or shell loads it in production).
    await provider.loadQueue();
    await pumpApp(
      tester,
      const AdminReviewDetailScreen(submissionId: 'sub-1'),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AdminReviewProvider>.value(value: provider),
      ],
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      // The notes field owns an inner scrollable; the ListView's own
      // Scrollable is the unique scrollable ancestor of any row widget.
      scrollable: find.ancestor(
        of: finder,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
  }

  group('AdminReviewDetailScreen Phase 4 actions', () {
    testWidgets('opening claims the submission for review', (
      WidgetTester tester,
    ) async {
      final FakeAdminReviewRepository repo = await pumpDetail(tester);
      expect(repo.startCallCount, greaterThanOrEqualTo(1));
      expect(repo.lastStartedId, 'sub-1');
      await unmount(tester);
    });

    testWidgets('reject forwards the resubmission choice', (
      WidgetTester tester,
    ) async {
      final FakeAdminReviewRepository repo = await pumpDetail(tester);
      expect(find.text('Require the applicant to resubmit'), findsOneWidget);

      await scrollTo(tester, find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await scrollTo(tester, find.text('Reject'));
      await tester.tap(find.text('Reject'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repo.rejectCallCount, 1);
      expect(repo.lastRequiresResubmission, isTrue);
      // Let the 500ms confirmation beat elapse before teardown.
      await tester.pump(const Duration(milliseconds: 600));
      await unmount(tester);
    });

    testWidgets('reject without the choice stays final', (
      WidgetTester tester,
    ) async {
      final FakeAdminReviewRepository repo = await pumpDetail(tester);
      await scrollTo(tester, find.text('Reject'));
      await tester.tap(find.text('Reject'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repo.rejectCallCount, 1);
      expect(repo.lastRequiresResubmission, isFalse);
      // Let the 500ms confirmation beat elapse before teardown.
      await tester.pump(const Duration(milliseconds: 600));
      await unmount(tester);
    });

    testWidgets('PDF documents render a copy-link row', (
      WidgetTester tester,
    ) async {
      await pumpDetail(
        tester,
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(
            submissionId: 'sub-1',
            documentPath: 'credentials/sub-1/doc.pdf',
          ),
        ],
      );
      await scrollTo(tester, find.text('Load document'));
      await tester.tap(find.text('Load document'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('PDF document'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.tap(find.text('Copy link'));
      await tester.pump();
      expect(find.text('Link copied'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Detail responsive matrix (Phase 5)', () {
    Future<void> pumpDetailAt(
      WidgetTester tester, {
      required double width,
      bool dark = false,
    }) async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        isAdmin: true,
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(
            submissionId: 'sub-1',
            entityName: 'Ada Lovelace',
            entityLegalName: 'Ada King',
          ),
        ],
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
      await provider.loadQueue();
      await pumpScreen(
        tester,
        const AdminReviewDetailScreen(submissionId: 'sub-1'),
        width: width,
        dark: dark,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<AdminReviewProvider>.value(value: provider),
        ],
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    for (final double width in <double>[390, 800, 1280]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpDetailAt(tester, width: width);
        await unmount(tester);
      });
    }

    testWidgets('no overflow at 1280dp in dark theme', (
      WidgetTester tester,
    ) async {
      await pumpDetailAt(tester, width: 1280, dark: true);
      await unmount(tester);
    });
  });
}
