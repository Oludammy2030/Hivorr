import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_overview_screen.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/responsive_harness.dart';
import '../../support/harnesses/widget_harness.dart';

/// Phase 4 Group 1 locks: professional Overview + Find Work already follow
/// the mobile contract (shared chrome, MobileCompact gutters, collapsing
/// grids, ellipsis-guarded rows), so this group verifies rather than
/// redesigns — no-overflow at 320/360/390/430, keyboard-safe search, and
/// respected safe areas. Any failure here is a real defect to fix, not an
/// assertion to loosen.
class _Group1DiscoveryService implements JobService {
  _Group1DiscoveryService(this.jobs);

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
  Future<ApplicationPage> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const ApplicationPage(applications: [], hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Group1HireService implements HireService {
  _Group1HireService(this.hires);

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

class _OfferOnboardingService implements OnboardingService {
  OnboardingProgress? _progress;

  @override
  OnboardingProgress? get progress => _progress;

  @override
  Future<OnboardingStepCode> resume(String entityId) async {
    _progress = OnboardingProgress(
      entityId: entityId,
      capability: EntityCapability.offer,
    );
    return OnboardingStepCode.capability;
  }

  @override
  void disposeProgress() => _progress = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Job _job({
  required String id,
  required String title,
  required int applications,
}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'client-1',
    title: title,
    description:
        'A genuinely long job description whose first line must clamp '
        'instead of overflowing narrow phone viewports.',
    budgetMin: 3000,
    budgetMax: 5000,
    currencyCode: 'USD',
    location: 'Lekki Phase 1, Lagos, Nigeria',
    status: 'open',
    applicationsCount: applications,
    postedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now,
  );
}

Hire _hire({required String id, required String status}) {
  return Hire(
    id: id,
    jobId: 'job-1',
    applicationId: 'app-job-1',
    clientEntityId: 'client-1',
    professionalEntityId: 'entity-1',
    status: status,
    hiredAt: DateTime.now().subtract(const Duration(days: 1)),
    jobTitle: 'Senior React Developer for Fintech Platform',
  );
}

Future<List<SingleChildWidget>> _offerProviders() async {
  final JobProvider jobs = JobProvider(
    service: _Group1DiscoveryService(<Job>[
      _job(
        id: 'job-1',
        title:
            'Senior React Developer for Fintech Platform with a very long title',
        applications: 12,
      ),
      _job(id: 'job-2', title: 'Solar Panel Installation — 20 Units', applications: 2),
    ]),
  );
  final HireProvider hires = HireProvider(
    service: _Group1HireService(<Hire>[
      _hire(id: 'hire-1', status: 'active'),
    ]),
  );
  final OnboardingProvider onboarding = OnboardingProvider(
    service: _OfferOnboardingService(),
  );
  await onboarding.loadProgress('entity-1');
  final AuthProvider auth = AuthProvider(service: FakeAuthService());
  addTearDown(() {
    jobs.dispose();
    hires.dispose();
    onboarding.dispose();
    auth.dispose();
  });
  return <SingleChildWidget>[
    ChangeNotifierProvider<JobProvider>.value(value: jobs),
    ChangeNotifierProvider<HireProvider>.value(value: hires),
    ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];
}

void main() {
  const List<double> widths = <double>[320, 360, 390, 430];

  group('Group 1 — professional Overview', () {
    for (final double width in widths) {
      testWidgets('no overflow at ${width.toInt()}dp', (tester) async {
        await pumpScreen(
          tester,
          const DashboardOverviewScreen(),
          width: width,
          providers: await _offerProviders(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Find New Work'), findsOneWidget);
      });
    }

    testWidgets('wide desktop rail renders without overflow', (tester) async {
      await pumpScreen(
        tester,
        const DashboardOverviewScreen(),
        width: 1024,
        height: 900,
        providers: await _offerProviders(),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
    });

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _offerProviders();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const DashboardOverviewScreen(),
        ),
      );
    });
  });

  group('Group 1 — Find Work', () {
    for (final double width in widths) {
      testWidgets('no overflow at ${width.toInt()}dp', (tester) async {
        await pumpScreen(
          tester,
          const OpportunitiesScreen(),
          width: width,
          providers: await _offerProviders(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('Find Work'), findsOneWidget);
        expect(find.text('Filter'), findsOneWidget);
      });
    }

    testWidgets('keyboard-open keeps search usable', (tester) async {
      final List<SingleChildWidget> providers = await _offerProviders();
      await expectKeyboardSafe(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const OpportunitiesScreen(),
        ),
      );
    });

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _offerProviders();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const OpportunitiesScreen(),
        ),
      );
    });
  });
}
