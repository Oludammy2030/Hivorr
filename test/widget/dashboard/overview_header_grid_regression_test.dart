import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
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
  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => JobPage(jobs: const <Job>[], hasMore: false, nextCursor: null);

  @override
  Future<ApplicationPage> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) async => ApplicationPage(
    applications: const <JobApplication>[],
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
  }) async => HirePage(hires: const <Hire>[], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _StubOnboardingService implements OnboardingService {
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

void main() {
  Future<void> pumpOverview(
    WidgetTester tester, {
    required double width,
  }) async {
    final JobProvider jobs = JobProvider(service: _StubJobService());
    addTearDown(jobs.dispose);
    final HireProvider hires = HireProvider(service: _StubHireService());
    addTearDown(hires.dispose);
    final OnboardingProvider onboarding = OnboardingProvider(
      service: _StubOnboardingService(),
    );
    addTearDown(onboarding.dispose);
    await onboarding.loadProgress('entity-1');
    final AuthProvider auth = AuthProvider(service: FakeAuthService());
    addTearDown(auth.dispose);
    await pumpScreen(
      tester,
      const DashboardOverviewScreen(),
      width: width,
      height: 844,
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ChangeNotifierProvider<HireProvider>.value(value: hires),
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
    );
    await tester.pumpAndSettle();
  }

  for (final double width in <double>[320, 360, 390, 414]) {
    testWidgets(
      'overview ${width.toInt()}px: single My Hivorr header + 2x2 stats, no overflow',
      (WidgetTester tester) async {
        await pumpOverview(tester, width: width);
        expect(tester.takeException(), isNull);

        // Single header: My Hivorr once, no refresh action.
        expect(find.text('My Hivorr'), findsOneWidget);
        expect(find.byTooltip('Refresh'), findsNothing);

        // 2x2 arrangement: row pairs share the same vertical center.
        final Offset jobsPosted = tester.getCenter(find.text('Jobs Posted'));
        final Offset activeHires = tester.getCenter(find.text('Active Hires'));
        final Offset totalSpent = tester.getCenter(find.text('Total Spent'));
        final Offset openApps = tester.getCenter(find.text('Open Apps'));
        expect(
          (jobsPosted.dy - activeHires.dy).abs(),
          lessThan(1.0),
          reason: 'Row 1 must be side-by-side at ${width.toInt()}px',
        );
        expect(
          (totalSpent.dy - openApps.dy).abs(),
          lessThan(1.0),
          reason: 'Row 2 must be side-by-side at ${width.toInt()}px',
        );
        expect(
          totalSpent.dy,
          greaterThan(jobsPosted.dy),
          reason: 'Row 2 must sit below Row 1 at ${width.toInt()}px',
        );
      },
    );
  }
}
