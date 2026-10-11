import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
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

/// Scripted [JobService]: trigger counts on the jobs, row statuses in the
/// per-job application lists. Fails [listMyJobs] when [failPosted] is set.
class _StubJobService implements JobService {
  _StubJobService(
    this.posted,
    this.applicationsByJob, {
    this.failPosted = false,
    this.blockPosted,
  });

  final List<Job> posted;
  final Map<String, List<JobApplication>> applicationsByJob;
  final bool failPosted;
  final Completer<JobPage>? blockPosted;

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    if (failPosted) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Offline.',
        code: 'NET',
      );
    }
    if (blockPosted != null) return blockPosted!.future;
    return JobPage(jobs: posted, hasMore: false, nextCursor: null);
  }

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

Job _job(String id, String title, {int apps = 0}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'entity-1',
    title: title,
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

JobApplication _app(
  String id,
  String jobId,
  String status, {
  String note = 'Cover note that is long enough.',
}) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: id,
    jobId: jobId,
    professionalEntityId: 'pro-$id',
    clientEntityId: 'entity-1',
    coverNote: note,
    quotedAmount: 3500,
    currencyCode: 'USD',
    status: status,
    submittedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now.subtract(const Duration(hours: 3)),
  );
}

void main() {
  group('Overview application counts', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late AuthProvider auth;
    int pumpSeq = 0;

    Future<void> pump(
      WidgetTester tester, {
      required List<Job> posted,
      Map<String, List<JobApplication>> apps = const {},
      bool failPosted = false,
      Completer<JobPage>? blockPosted,
      double width = 1440,
    }) async {
      // Fresh key per pump: re-pumping the same tester with an identical
      // typeless widget would reuse the old State (skipping hydration and
      // stranding the new providers idle). Real navigation remounts.
      final int seq = pumpSeq++;
      jobs = JobProvider(
        service: _StubJobService(
          posted,
          apps,
          failPosted: failPosted,
          blockPosted: blockPosted,
        ),
      );
      hires = HireProvider(service: _StubHireService());
      onboarding = OnboardingProvider(service: _StubOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = AuthProvider(service: FakeAuthService());
      await pumpScreen(
        tester,
        DashboardOverviewScreen(key: ValueKey<int>(seq)),
        width: width,
        height: 900,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
    }

    void disposeAll() {
      jobs.dispose();
      hires.dispose();
      onboarding.dispose();
      auth.dispose();
    }

    testWidgets('Scenario 1: no applications shows zeros + State A', (
      tester,
    ) async {
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Senior React Developer')],
      );
      addTearDown(disposeAll);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('0 Applicants'), findsOneWidget);
      expect(find.text('0 applied'), findsOneWidget);
      expect(find.text('Open Jobs'), findsOneWidget);
      expect(find.text('No new applications across your active jobs yet'),
          findsOneWidget);
    });

    testWidgets('Scenario 2: three awaiting share card, hero, Open Jobs', (
      tester,
    ) async {
      for (final double width in <double>[390, 1440]) {
        await pump(
          tester,
          width: width,
          posted: <Job>[_job('job-1', 'Senior React Developer', apps: 3)],
          apps: <String, List<JobApplication>>{
            'job-1': <JobApplication>[
              _app('a1', 'job-1', 'submitted'),
              _app('a2', 'job-1', 'submitted'),
              _app('a3', 'job-1', 'shortlisted'),
            ],
          },
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'width ${width.toInt()}',
        );
        expect(find.text('3 Applicants'), findsOneWidget);
        expect(find.text('3 applied'), findsOneWidget);
        expect(
          find.text(
            'You have 3 new applications across your active jobs',
            findRichText: true,
          ),
          findsOneWidget,
        );
        // Open Jobs counts open jobs, not applications.
        expect(find.text('Open Jobs'), findsOneWidget);
        disposeAll();
      }
    });

    testWidgets('Scenario 3: counts split per job, total without doubling', (
      tester,
    ) async {
      await pump(
        tester,
        posted: <Job>[
          _job('job-1', 'Senior React Developer', apps: 2),
          _job('job-2', 'Office Renovation Job', apps: 3),
        ],
        apps: <String, List<JobApplication>>{
          'job-1': <JobApplication>[
            _app('a1', 'job-1', 'submitted'),
            _app('a2', 'job-1', 'submitted'),
          ],
          'job-2': <JobApplication>[
            _app('b1', 'job-2', 'submitted'),
            _app('b2', 'job-2', 'submitted'),
            _app('b3', 'job-2', 'shortlisted'),
          ],
        },
      );
      addTearDown(disposeAll);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2 Applicants'), findsOneWidget);
      expect(find.text('3 Applicants'), findsOneWidget);
      expect(
        find.text(
          'You have 5 new applications across your active jobs',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Scenario 4/5: reviewed-only shows State C, mixed stays B', (
      tester,
    ) async {
      // All reviewed: totals preserved, banner names the reviewed state.
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Senior React Developer', apps: 2)],
        apps: <String, List<JobApplication>>{
          'job-1': <JobApplication>[
            _app('a1', 'job-1', 'rejected'),
            _app('a2', 'job-1', 'rejected'),
          ],
        },
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2 Applicants'), findsOneWidget);
      expect(
        find.text("You've reviewed all 2 applications."),
        findsOneWidget,
      );
      expect(find.textContaining('No new applications'), findsNothing);
      disposeAll();

      // Mixed: one actionable keeps State B; withdrawn never counts.
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Senior React Developer', apps: 3)],
        apps: <String, List<JobApplication>>{
          'job-1': <JobApplication>[
            _app('a1', 'job-1', 'submitted'),
            _app('a2', 'job-1', 'rejected'),
            _app('a3', 'job-1', 'withdrawn'),
          ],
        },
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'You have 3 new applications across your active jobs',
          findRichText: true,
        ),
        findsOneWidget,
      );
      disposeAll();
    });

    testWidgets('Scenario 7: loading shows ellipses, never zero', (
      tester,
    ) async {
      final Completer<JobPage> gate = Completer<JobPage>();
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Senior React Developer', apps: 3)],
        apps: <String, List<JobApplication>>{
          'job-1': <JobApplication>[_app('a1', 'job-1', 'submitted')],
        },
        blockPosted: gate,
      );
      addTearDown(disposeAll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('…'), findsWidgets);
      expect(find.text('0 Applicants'), findsNothing);
      expect(find.text('No new applications across your active jobs yet'),
          findsNothing);
      gate.complete(
        JobPage(
          jobs: <Job>[_job('job-1', 'Senior React Developer', apps: 3)],
          hasMore: false,
          nextCursor: null,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'You have 3 new applications across your active jobs',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Scenario 7: failed load surfaces error, not zeros', (
      tester,
    ) async {
      await pump(tester, posted: const <Job>[], failPosted: true);
      addTearDown(disposeAll);
      await tester.pumpAndSettle();
      expect(find.text('Could not load dashboard'), findsOneWidget);
      expect(find.text('0 Applicants'), findsNothing);
    });
  });
}
