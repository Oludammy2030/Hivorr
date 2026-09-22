import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
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
    testWidgets('renders the app bar title', (WidgetTester tester) async {
      await pumpScreenWith(tester);
      expect(find.text('Verification & Approvals'), findsOneWidget);
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
      expect(find.textContaining('trade_proof'), findsWidgets);
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

      // Before the post-frame callback completes, loading shows first.
      await tester.pump();
      expect(find.text('Verification & Approvals'), findsOneWidget);
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
