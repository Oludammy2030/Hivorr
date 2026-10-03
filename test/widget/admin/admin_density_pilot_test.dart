import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/admin_config_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/systems/admin/screens/admin_dashboard_screen.dart';
import 'package:hivorr/systems/admin/screens/admin_jobs_screen.dart';
import 'package:hivorr/systems/admin/screens/admin_payments_screen.dart';
import 'package:hivorr/systems/admin/screens/admin_settings_screen.dart';
import 'package:hivorr/systems/admin/screens/manage_user_screen.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/fakes/fake_manage_user.dart';
import '../../test_helpers.dart';

/// In-memory discovery read for admin queue tests.
class _StubJobService implements JobService {
  _StubJobService(this.jobs);

  final List<Job> jobs;

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async => JobPage(jobs: jobs, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Job _queueJob({
  required String id,
  required String title,
  required String status,
  double? budget,
}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'client-1',
    title: title,
    description: 'Seeded admin moderation queue job.',
    budgetMin: budget,
    budgetMax: budget,
    currencyCode: 'USD',
    location: 'Remote',
    status: status,
    applicationsCount: 3,
    postedAt: now.subtract(const Duration(hours: 2)),
    createdAt: now.subtract(const Duration(hours: 2)),
    updatedAt: now,
  );
}

/// Phase-2 pilot verification: the migrated Admin Dashboard + Users screens
/// render without overflow at phone, tablet, and desktop widths, in light
/// and dark themes (VISUAL-IDENTITY.md §24a viewport checklist).
void main() {
  List<SingleChildWidget> adminProviders({
    FakeManageUserRepository? manageRepo,
    FakeAdminReviewRepository? adminRepo,
  }) {
    final ManageUserProvider manageProvider = ManageUserProvider(
      repo: manageRepo ?? FakeManageUserRepository(),
    );
    final AdminReviewProvider adminProvider = AdminReviewProvider(
      repo: adminRepo ?? FakeAdminReviewRepository(isAdmin: true),
    );
    return <SingleChildWidget>[
      ChangeNotifierProvider<ManageUserProvider>.value(value: manageProvider),
      ChangeNotifierProvider<AdminReviewProvider>.value(value: adminProvider),
    ];
  }

  Future<void> expectNoOverflow(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  group('ManageUserScreen pilot', () {
    for (final double width in <double>[390, 800, 1280]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const ManageUserScreen(),
          width: width,
          providers: adminProviders(),
        );
        await expectNoOverflow(tester);
      });
    }

    // The 6-column dual-action table needs ≥900dp (content-driven §21a
    // exception); 800dp renders narrow cards.
    testWidgets('no overflow with rows at 1024dp', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ManageUserScreen(),
        width: 1024,
        providers: adminProviders(
          manageRepo: FakeManageUserRepository(
            users: <ManageUserListItem>[
              manageUserListItem(
                id: 'u1',
                displayName: 'Ada Lovelace',
                status: 'active',
              ),
              manageUserListItem(
                id: 'u2',
                displayName: 'Grace Hopper',
                status: 'suspended',
              ),
            ],
          ),
        ),
      );
      await expectNoOverflow(tester);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('no overflow with narrow cards at 390dp', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ManageUserScreen(),
        width: 390,
        providers: adminProviders(
          manageRepo: FakeManageUserRepository(
            users: <ManageUserListItem>[
              manageUserListItem(id: 'u1', displayName: 'Ada Lovelace'),
            ],
          ),
        ),
      );
      await expectNoOverflow(tester);
    });
  });

  group('AdminDashboardScreen pilot', () {
    for (final double width in <double>[390, 800, 1280]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const AdminDashboardScreen(),
          width: width,
          providers: adminProviders(),
        );
        await expectNoOverflow(tester);
      });
    }

    testWidgets('no overflow at 1280dp in dark theme', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const AdminDashboardScreen(),
        width: 1280,
        dark: true,
        providers: adminProviders(),
      );
      await expectNoOverflow(tester);
    });
  });

  group('AdminJobsScreen pilot', () {
    List<SingleChildWidget> jobProviders() {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(<Job>[
          _queueJob(
            id: 'job-1',
            title: 'Senior React Developer',
            status: 'open',
            budget: 3500,
          ),
          _queueJob(
            id: 'job-2',
            title: 'Brand Identity Design Package',
            status: 'completed',
          ),
          _queueJob(
            id: 'job-3',
            title: 'Home Plumbing Emergency Fix',
            status: 'paused',
            budget: 800,
          ),
        ]),
      );
      addTearDown(jobs.dispose);
      return <SingleChildWidget>[
        ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ChangeNotifierProvider<AdminReviewProvider>.value(
          value: AdminReviewProvider(
            repo: FakeAdminReviewRepository(isAdmin: true),
          ),
        ),
      ];
    }

    // 1 col <600, 2 cols 600–1023, 3 cols ≥1024.
    for (final double width in <double>[390, 800, 1280]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const AdminJobsScreen(),
          width: width,
          providers: jobProviders(),
        );
        await expectNoOverflow(tester);
      });
    }

    testWidgets('renders the queue count and View/Remove actions', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const AdminJobsScreen(),
        width: 1280,
        providers: jobProviders(),
      );
      await expectNoOverflow(tester);
      expect(find.text('3 total jobs'), findsOneWidget);
      expect(find.text('View'), findsNWidgets(3));
      expect(find.text('Remove'), findsNWidgets(2));
    });
  });

  group('AdminPaymentsScreen pilot', () {
    List<SingleChildWidget> paymentProviders() {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(<Job>[
          _queueJob(
            id: 'job-1',
            title: 'Seeded demand job',
            status: 'open',
            budget: 3500,
          ),
        ]),
      );
      addTearDown(jobs.dispose);
      final ManageUserProvider users = ManageUserProvider(
        repo: FakeManageUserRepository(
          users: <ManageUserListItem>[
            manageUserListItem(id: 'u1', displayName: 'Ada Lovelace'),
            manageUserListItem(
              id: 'u2',
              displayName: 'Grace Hopper',
              kycTier: 'tier_2',
            ),
          ],
        ),
      );
      return <SingleChildWidget>[
        ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ChangeNotifierProvider<ManageUserProvider>.value(value: users),
        ChangeNotifierProvider<AdminReviewProvider>.value(
          value: AdminReviewProvider(
            repo: FakeAdminReviewRepository(isAdmin: true),
          ),
        ),
      ];
    }

    for (final double width in <double>[390, 800, 1280]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const AdminPaymentsScreen(),
          width: width,
          providers: paymentProviders(),
        );
        await expectNoOverflow(tester);
      });
    }
  });

  group('AdminSettingsScreen pilot', () {
    Future<List<SingleChildWidget>> settingsProviders() async {
      final AdminConfigProvider config = AdminConfigProvider(
        storage: FakeStorageEngine(),
      );
      await config.load();
      addTearDown(config.dispose);
      return <SingleChildWidget>[
        ChangeNotifierProvider<AdminConfigProvider>.value(value: config),
        ChangeNotifierProvider<AdminReviewProvider>.value(
          value: AdminReviewProvider(
            repo: FakeAdminReviewRepository(isAdmin: true),
          ),
        ),
      ];
    }

    for (final double width in <double>[390, 800]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const AdminSettingsScreen(),
          width: width,
          providers: await settingsProviders(),
        );
        await expectNoOverflow(tester);
      });
    }

    testWidgets('renders the fee, toggle, and security cards', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const AdminSettingsScreen(),
        width: 800,
        providers: await settingsProviders(),
      );
      await expectNoOverflow(tester);
      expect(find.text('Fee Configuration'), findsOneWidget);
      expect(find.text('Platform Toggles'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Save Configuration'), findsOneWidget);
    });
  });
}
