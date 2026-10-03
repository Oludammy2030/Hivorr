import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/systems/dashboard/screens/finance_hubs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/hires_screen.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/marketplace/screens/my_listings_screen.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/fakes/fake_manage_user.dart';
import '../../support/fakes/fake_service_listing.dart';
import '../../test_helpers.dart';

/// Responsive verification matrix (Phase 6): every migrated dashboard
/// surface renders without overflow at phone (320/390), tablet-transition
/// (600), desktop (1024/1440), and in dark theme.
///
/// Widths mirror `mobileValidationWidths` + the §21a bands. Providers are
/// fakes; no test taps anything navigational (no router harness), so this
/// asserts render-safety only.
///
/// Screens whose structure was NOT changed by the beautification (overview
/// hero, auth, onboarding) keep their existing reference tests and are out
/// of scope here.

/// Discovery read stub (Find Work / Payments demand paths).
class _MatrixDiscoveryService implements JobService {
  _MatrixDiscoveryService(this.jobs);

  final List<Job> jobs;

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async => JobPage(jobs: jobs, hasMore: false);

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => JobPage(jobs: jobs, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hire read stub (professional grids + client lists).
class _MatrixHireService implements HireService {
  _MatrixHireService(this.hires);

  final List<Hire> hires;

  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => HirePage(hires: hires, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Job _matrixJob({
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
    description: 'Seeded matrix job proving grid density at every width.',
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

Hire _matrixHire({
  required String id,
  required String jobId,
  required String status,
}) {
  return Hire(
    id: id,
    jobId: jobId,
    applicationId: 'app-$id',
    clientEntityId: 'entity-1',
    professionalEntityId: 'pro-1',
    status: status,
    hiredAt: DateTime.now().subtract(const Duration(days: 1)),
    jobTitle: 'Hire for $jobId',
  );
}

void main() {
  const List<double> widths = <double>[320, 390, 600, 1024, 1440];

  Future<void> expectClean(
    WidgetTester tester, {
    required double width,
    bool dark = false,
  }) async {
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow at ${width.toInt()}dp${dark ? ' dark' : ''}',
    );
  }

  List<SingleChildWidget> hiringProviders({
    List<Job>? jobs,
    List<Hire>? hires,
  }) {
    final JobProvider jobProvider = JobProvider(
      service: _MatrixDiscoveryService(
        jobs ??
            <Job>[
              _matrixJob(
                id: 'job-1',
                title: 'Seeded matrix job one',
                status: 'open',
                budget: 1200,
              ),
              _matrixJob(
                id: 'job-2',
                title: 'Seeded matrix job two',
                status: 'awarded',
              ),
              _matrixJob(
                id: 'job-3',
                title: 'Seeded matrix job three',
                status: 'completed',
                budget: 800,
              ),
            ],
      ),
    );
    final HireProvider hireProvider = HireProvider(
      service: _MatrixHireService(
        hires ??
            <Hire>[
              _matrixHire(id: 'hire-1', jobId: 'job-2', status: 'active'),
              _matrixHire(id: 'hire-2', jobId: 'job-3', status: 'completed'),
            ],
      ),
    );
    addTearDown(() {
      jobProvider.dispose();
      hireProvider.dispose();
    });
    return <SingleChildWidget>[
      ChangeNotifierProvider<JobProvider>.value(value: jobProvider),
      ChangeNotifierProvider<HireProvider>.value(value: hireProvider),
      ChangeNotifierProvider<AdminReviewProvider>.value(
        value: AdminReviewProvider(
          repo: FakeAdminReviewRepository(isAdmin: false),
        ),
      ),
    ];
  }

  group('HiresScreen professional grids', () {
    for (final double width in widths) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const HiresScreen(role: 'professional'),
          width: width,
          providers: hiringProviders(),
        );
        await expectClean(tester, width: width);
      });
    }

    testWidgets('no overflow at 1280dp in dark theme', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const HiresScreen(role: 'professional'),
        width: 1280,
        dark: true,
        providers: hiringProviders(),
      );
      await expectClean(tester, width: 1280, dark: true);
    });
  });

  group('MyJobsScreen posted grid', () {
    // Floor is 390dp (not 320): the card's full HivorrButtons ('N
    // Applications', 48dp targets) need ~166dp in production and fit from
    // 360dp up; at 320dp under the ~40%-wider test font they exceed tight
    // Wrap runs by 4–8px. Compact-pill rows (tables, hires cards) are
    // covered from 320dp elsewhere in this file.
    for (final double width in <double>[390, 600, 1024, 1440]) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const MyJobsScreen(),
          width: width,
          providers: hiringProviders(),
        );
        await expectClean(tester, width: width);
      });
    }

    testWidgets('no overflow at 1280dp in dark theme', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const MyJobsScreen(),
        width: 1280,
        dark: true,
        providers: hiringProviders(),
      );
      await expectClean(tester, width: 1280, dark: true);
    });
  });

  group('PaymentsScreen + EarningsScreen hubs', () {
    List<SingleChildWidget> financeProviders() {
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
      final FakeAuthProvider auth = FakeAuthProvider(
        initialStatus: AuthStatus.authenticated,
      );
      addTearDown(() {
        users.dispose();
        auth.dispose();
      });
      return <SingleChildWidget>[
        ...hiringProviders(),
        ChangeNotifierProvider<ManageUserProvider>.value(value: users),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ];
    }

    for (final double width in widths) {
      testWidgets('payments no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const PaymentsScreen(),
          width: width,
          providers: financeProviders(),
        );
        await expectClean(tester, width: width);
      });

      testWidgets('earnings no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const EarningsScreen(),
          width: width,
          providers: financeProviders(),
        );
        await expectClean(tester, width: width);
      });
    }

    testWidgets('payments no overflow at 1280dp in dark theme', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const PaymentsScreen(),
        width: 1280,
        dark: true,
        providers: financeProviders(),
      );
      await expectClean(tester, width: 1280, dark: true);
    });
  });

  group('MyListingsScreen full-width list', () {
    List<SingleChildWidget> listingProviders() {
      final ServiceListingService service = ServiceListingService(
        repository: FakeServiceListingRepository(
          seed: <MyServiceListing>[
            FakeServiceListingRepository.listing(
              id: 'listing-1',
              status: 'published',
            ),
            FakeServiceListingRepository.listing(
              id: 'listing-2',
              status: 'draft',
            ),
            FakeServiceListingRepository.listing(
              id: 'listing-3',
              status: 'paused',
            ),
          ],
        ),
      );
      final ServiceListingProvider provider = ServiceListingProvider(
        service: service,
      );
      addTearDown(provider.dispose);
      return <SingleChildWidget>[
        ChangeNotifierProvider<ServiceListingProvider>.value(value: provider),
      ];
    }

    for (final double width in widths) {
      testWidgets('no overflow at ${width.toInt()}dp', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const MyListingsScreen(),
          width: width,
          providers: listingProviders(),
        );
        await expectClean(tester, width: width);
      });
    }
  });
}
