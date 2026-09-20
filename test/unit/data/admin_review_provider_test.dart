import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';

import '../../support/fakes/fake_admin_review.dart';

void main() {
  group('AdminReviewProvider', () {
    test('checkAdmin surfaces the admin flag', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        isAdmin: true,
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      expect(provider.isAdmin, isNull);

      await provider.checkAdmin();

      expect(provider.isAdmin, isTrue);
      expect(repo.checkAdminCallCount, 1);
    });

    test('checkAdmin fails closed on non-admin', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        isAdmin: false,
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      await provider.checkAdmin();

      expect(provider.isAdmin, isFalse);
    });

    test('checkAdmin fails closed on ApiException', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        isAdmin: true,
        nextError: const ApiException(
          kind: ApiExceptionKind.forbidden,
          message: 'denied',
          code: 'PLT002',
        ),
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      await provider.checkAdmin();

      expect(provider.isAdmin, isFalse);
    });

    test('loadQueue populates the queue and pagination', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'One'),
          adminQueueEntry(submissionId: 'sub-2', entityName: 'Two'),
        ],
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      await provider.loadQueue();

      expect(provider.queue.length, 2);
      expect(provider.queue.first.entityName, 'One');
      expect(provider.lastError, isNull);
      expect(repo.queueCallCount, 1);
    });

    test(
      'loadQueue surfaces errors without leaving stale data behind',
      () async {
        final FakeAdminReviewRepository repo = FakeAdminReviewRepository()
          ..nextError = const ApiException(
            kind: ApiExceptionKind.server,
            message: 'boom',
            code: 'PLT999',
          );
        final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

        await provider.loadQueue();

        expect(provider.lastError, isNotNull);
        expect(provider.queue, isEmpty);
        expect(provider.isLoadingQueue, isFalse);
      },
    );

    test('approveSubmission removes the entry from the queue', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'One'),
        ],
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
      await provider.loadQueue();
      expect(provider.queue.length, 1);

      await provider.approveSubmission('sub-1', notes: 'ok');

      expect(repo.approveCallCount, 1);
      expect(repo.lastApprovedId, 'sub-1');
      expect(provider.queue, isEmpty);
      expect(provider.isActing, isFalse);
    });

    test(
      'rejectSubmission removes the entry and forwards resubmit flag',
      () async {
        final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(submissionId: 'sub-1', entityName: 'One'),
          ],
        );
        final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
        await provider.loadQueue();

        await provider.rejectSubmission(
          'sub-1',
          notes: 'bad doc',
          requiresResubmission: true,
        );

        expect(repo.rejectCallCount, 1);
        expect(repo.lastRejectedId, 'sub-1');
        expect(repo.lastRequiresResubmission, isTrue);
        expect(provider.queue, isEmpty);
      },
    );

    test('loadAuditTrail exposes the audit entries', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository()
        ..setAuditTrail(<AdminReviewAuditEntry>[
          adminAuditEntry(id: 'a1', eventType: 'submitted'),
        ]);
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      await provider.loadAuditTrail('sub-1');

      expect(provider.auditTrail.length, 1);
      expect(provider.auditTrail.first.eventType, 'submitted');
      expect(provider.activeSubmissionId, 'sub-1');
    });
  });
}
