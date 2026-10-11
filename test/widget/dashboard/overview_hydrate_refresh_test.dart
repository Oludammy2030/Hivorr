import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_overview_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/widget_harness.dart';

class _StubJobService implements JobService {
  _StubJobService(this.posted, this.applicationsByJob);

  final List<Job> posted;
  final Map<String, List<JobApplication>> applicationsByJob;

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false, nextCursor: null);

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => JobPage(jobs: posted, hasMore: false, nextCursor: null);

  @override
  Future<ApplicationPage> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) async => ApplicationPage(
    applications: applicationsByJob[jobId] ?? const <JobApplication>[],
    hasMore: false,
    nextCursor: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _StubHireService implements HireService {
  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const HirePage(hires: [], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _StubOnboardingService implements OnboardingService {
  _StubOnboardingService({bool hydrate = true}) {
    if (hydrate) {
      _progress = OnboardingProgress(
        entityId: 'entity-1',
        capability: EntityCapability.hire,
      );
    }
  }

  OnboardingProgress? _progress;

  @override
  OnboardingProgress? get progress => _progress;

  @override
  Future<OnboardingStepCode> resume(String entityId) async {
    _progress = OnboardingProgress(
      entityId: entityId,
      capability: EntityCapability.hire,
    );
    return OnboardingStepCode.capability;
  }

  @override
  void disposeProgress() => _progress = null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Job _job(String id, {int apps = 0}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'entity-1',
    title: 'Senior React Developer',
    description: 'Build and ship Hivorr web experiences for our team.',
    budgetMin: 3500,
    budgetMax: 3500,
    currencyCode: 'USD',
    location: 'Remote',
    status: 'open',
    applicationsCount: apps,
    postedAt: now.subtract(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
  );
}

JobApplication _app(String id, String status) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: id,
    jobId: 'job-1',
    professionalEntityId: 'pro-$id',
    clientEntityId: 'entity-1',
    coverNote: 'Cover note that is long enough.',
    quotedAmount: 3500,
    currencyCode: 'USD',
    status: status,
    submittedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now.subtract(const Duration(hours: 3)),
  );
}

void main() {
  group('Overview hydration and foreground refresh', () {
    testWidgets('null focus still loads posted (no gate drop)', (
      tester,
    ) async {
      // Fresh login: onboarding progress unknown, so hire + offer loads
      // contend. Serialization must let loadMine(posted) through.
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-1', apps: 1)],
          <String, List<JobApplication>>{
            'job-1': <JobApplication>[_app('a1', 'shortlisted')],
          },
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final OnboardingProvider onboarding = OnboardingProvider(
        service: _StubOnboardingService(hydrate: false),
      );
      final AuthProvider auth = AuthProvider(service: FakeAuthService());
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await pumpScreen(
        tester,
        const DashboardOverviewScreen(),
        width: 1440,
        height: 900,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The posted list survived the parallel offer-side loads: shortlisted
      // rows count, and the combined hiring section shows the total.
      expect(jobs.posted, hasLength(1));
      expect(jobs.posted.first.applicationsCount, 1);
      expect(find.text('1 applications'), findsOneWidget);
    });

    testWidgets('foreground resume picks up a new submission', (
      tester,
    ) async {
      final List<Job> posted = <Job>[_job('job-1')];
      final Map<String, List<JobApplication>> apps =
          <String, List<JobApplication>>{};
      final JobProvider jobs = JobProvider(
        service: _StubJobService(posted, apps),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final OnboardingProvider onboarding = OnboardingProvider(
        service: _StubOnboardingService(),
      );
      await onboarding.loadProgress('entity-1');
      final AuthProvider auth = AuthProvider(service: FakeAuthService());
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await pumpScreen(
        tester,
        const DashboardOverviewScreen(),
        width: 1440,
        height: 900,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No new applications across your active jobs yet'),
          findsOneWidget);

      // A professional applies while the app sits backgrounded; the
      // server trigger moves the count. Foregrounding must surface it.
      apps['job-1'] = <JobApplication>[_app('a1', 'shortlisted')];
      posted[0] = _job('job-1', apps: 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1 applied'), findsOneWidget);
      expect(
        find.text(
          'You have 1 new application across your active jobs',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('No new applications across your active jobs yet'),
          findsNothing);
    });
  });
}
