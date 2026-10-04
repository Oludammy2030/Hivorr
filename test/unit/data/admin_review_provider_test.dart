import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/fakes/fake_notifications.dart';

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

    test(
      'loadQueue preserves registered-identity comparison fields',
      () async {
        final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(
              submissionId: 'sub-1',
              entityName: 'One',
              entityLegalName: 'One Legal',
              professionName: 'Plumbing',
            ),
          ],
        );
        final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

        await provider.loadQueue();

        final AdminReviewQueueEntry entry = provider.queue.single;
        expect(entry.entityLegalName, 'One Legal');
        expect(entry.professionName, 'Plumbing');
      },
    );

    test(
      'startReview writes server-vocabulary in_review and keeps fields',
      () async {
        final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
          queue: <AdminReviewQueueEntry>[
            adminQueueEntry(
              submissionId: 'sub-1',
              entityName: 'One',
              entityLegalName: 'One Legal',
            ),
          ],
        );
        final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
        await provider.loadQueue();

        await provider.startReview('sub-1');

        final AdminReviewQueueEntry entry = provider.queue.single;
        expect(entry.status, 'in_review');
        expect(entry.entityLegalName, 'One Legal');
        expect(provider.activeSubmissionId, 'sub-1');
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

    test('loadQueue forwards search, profession, and sort filters', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'One'),
        ],
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      await provider.loadQueue(
        search: 'ada',
        professionId: 'prof-1',
        sort: 'name',
      );

      expect(repo.lastSearch, 'ada');
      expect(repo.lastProfessionId, 'prof-1');
      expect(repo.lastSort, 'name');
      expect(provider.queue.length, 1);
    });

    test('loadMetrics exposes throughput metrics and prefers them', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'One'),
        ],
      )..metricsResult = const AdminReviewMetrics(
        pendingTotal: 7,
        inReviewTotal: 2,
        avgVerificationSeconds: 129600,
        approvedToday: 3,
        decidedTotal: 10,
        rejectedTotal: 4,
        rejectionRate: 0.4,
        periodDays: 30,
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

      expect(provider.metrics, isNull);

      await provider.loadMetrics();

      expect(repo.metricsCallCount, 1);
      expect(provider.metrics, isNotNull);
      expect(provider.metrics!.approvedToday, 3);
      expect(provider.metrics!.rejectionRate, 0.4);
      // Metrics pending total wins over the loaded-page length.
      expect(provider.pendingTotal, 7);
      expect(provider.isLoadingMetrics, isFalse);
    });

    test('loadMetrics surfaces errors without clearing the queue', () async {
      final FakeAdminReviewRepository repo = FakeAdminReviewRepository(
        queue: <AdminReviewQueueEntry>[
          adminQueueEntry(submissionId: 'sub-1', entityName: 'One'),
        ],
      );
      final AdminReviewProvider provider = AdminReviewProvider(repo: repo);
      await provider.loadQueue();
      expect(provider.queue.length, 1);

      repo.nextError = const ApiException(
        kind: ApiExceptionKind.server,
        message: 'boom',
        code: 'PLT999',
      );
      await provider.loadMetrics();

      expect(provider.lastError, isNotNull);
      expect(provider.metrics, isNull);
      expect(provider.queue.length, 1);
      expect(provider.isLoadingMetrics, isFalse);
    });

    group('review profile', () {
      test('loadReviewProfile exposes experiences, educations, skills',
          () async {
        final FakeAdminReviewRepository repo = FakeAdminReviewRepository()
          ..setReviewProfile(adminReviewProfile());
        final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

        await provider.loadReviewProfile('sub-1');

        expect(repo.profileCallCount, 1);
        expect(repo.lastProfileId, 'sub-1');
        expect(provider.reviewProfile.experiences.single.title,
            'Senior Plumber');
        expect(provider.reviewProfile.educations.single.school,
            'Trade Institute');
        expect(
            provider.reviewProfile.skills.single.name, 'Pipefitting');
        expect(provider.isLoadingProfile, isFalse);
        provider.dispose();
      });

      test('loadReviewProfile falls back to empty on error', () async {
        final FakeAdminReviewRepository repo = FakeAdminReviewRepository()
          ..setReviewProfile(adminReviewProfile())
          ..nextError = const ApiException(
            kind: ApiExceptionKind.server,
            message: 'boom',
            code: 'PLT999',
          );
        final AdminReviewProvider provider = AdminReviewProvider(repo: repo);

        await provider.loadReviewProfile('sub-1');

        expect(provider.reviewProfile.experiences, isEmpty);
        expect(provider.lastError, isNotNull);
        expect(provider.isLoadingProfile, isFalse);
        provider.dispose();
      });
    });

    group('new-submission notifications', () {
      NotificationProvider buildNotifications(FakeNotificationService service) {
        return NotificationProvider(
          service,
          NotificationPermissionManager(
            platform: FakeNotificationPermissionPlatform(),
          ),
        );
      }

      AdminReviewMetrics metricsWith({required int pending}) =>
          AdminReviewMetrics(
            pendingTotal: pending,
            inReviewTotal: 0,
            approvedToday: 0,
            decidedTotal: 0,
            rejectedTotal: 0,
            periodDays: 30,
          );

      test('first load sets the baseline silently', () async {
        final service = FakeNotificationService();
        final repo = FakeAdminReviewRepository()
          ..metricsResult = metricsWith(pending: 4);
        final provider = AdminReviewProvider(
          repo: repo,
          notificationProvider: buildNotifications(service),
        );

        await provider.loadMetrics();

        expect(service.shown, isEmpty);
        provider.dispose();
      });

      test('notifies once when the pending total grows', () async {
        final service = FakeNotificationService();
        final repo = FakeAdminReviewRepository()
          ..metricsResult = metricsWith(pending: 2);
        final provider = AdminReviewProvider(
          repo: repo,
          notificationProvider: buildNotifications(service),
        );

        await provider.loadMetrics();
        repo.metricsResult = metricsWith(pending: 5);
        await provider.loadMetrics();
        await provider.loadMetrics();

        expect(service.shown, hasLength(1));
        expect(service.shown.single.title, 'New verification submissions');
        expect(
          service.shown.single.body,
          '5 submissions are awaiting review.',
        );
        expect(service.shown.single.actionRoute, '/admin/review-queue');
        provider.dispose();
      });

      test('stays silent on flat or shrinking totals', () async {
        final service = FakeNotificationService();
        final repo = FakeAdminReviewRepository()
          ..metricsResult = metricsWith(pending: 5);
        final provider = AdminReviewProvider(
          repo: repo,
          notificationProvider: buildNotifications(service),
        );

        await provider.loadMetrics();
        await provider.loadMetrics();
        repo.metricsResult = metricsWith(pending: 3);
        await provider.loadMetrics();

        expect(service.shown, isEmpty);
        provider.dispose();
      });

      test('polling refreshes metrics until stopped', () async {
        final repo = FakeAdminReviewRepository();
        final provider = AdminReviewProvider(
          repo: repo,
          pollInterval: const Duration(milliseconds: 20),
        );

        provider.startPolling();
        provider.startPolling();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        provider.stopPolling();
        final int calls = repo.metricsCallCount;
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(calls, greaterThanOrEqualTo(1));
        expect(repo.metricsCallCount, calls);
        provider.dispose();
      });
    });
  });
}
