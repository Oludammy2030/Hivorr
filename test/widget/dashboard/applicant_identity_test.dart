import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';

class _StubJobService implements JobService {
  _StubJobService(this.posted, [this.byJob = const {}]);

  final List<Job> posted;
  final Map<String, List<JobApplication>> byJob;

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
    applications: byJob[jobId] ?? const <JobApplication>[],
    hasMore: false,
    nextCursor: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Portfolio stub: pro-1 has an approved public profile; pro-2 is gated
/// (returns `null`, mirroring the repository's `PLT004 → null` mapping).
class _StubPortfolioRepository implements PortfolioRepository {
  @override
  Future<PublicProfile?> getPublicProfile(String entityId) async {
    if (entityId == 'pro-1') {
      return const PublicProfile(
        entityId: 'pro-1',
        displayName: 'Adaeze Okafor',
        professionSlug: 'electrician',
        professionName: 'Electrician',
        industrySlug: 'construction',
        industryName: 'Construction',
      );
    }
    return null;
  }
}

/// Fails the test if the inbox issues any profile RPC: snapshot-carrying
/// rows must render with zero follow-up reads.
class _NoRpcPortfolioRepository implements PortfolioRepository {
  @override
  Future<PublicProfile?> getPublicProfile(String entityId) =>
      throw StateError('unexpected profile RPC for $entityId');
}

Job _job(String id, String title) {
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
    applicationsCount: 1,
    postedAt: now.subtract(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
  );
}

JobApplication _app(String id, String jobId, String proId, String note) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: id,
    jobId: jobId,
    professionalEntityId: proId,
    clientEntityId: 'entity-1',
    coverNote: note,
    quotedAmount: 3500,
    currencyCode: 'USD',
    status: 'submitted',
    submittedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now.subtract(const Duration(hours: 3)),
  );
}

/// Application row carrying the submit-time identity snapshot
/// (`20261010090001`): renders with zero profile RPCs.
JobApplication _appSnap(
  String id,
  String jobId,
  String proId,
  String note, {
  String? displayName = 'Chidi Eze',
  String? professionName = 'Plumber',
  String? professionSlug = 'plumber',
}) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: id,
    jobId: jobId,
    professionalEntityId: proId,
    clientEntityId: 'entity-1',
    coverNote: note,
    quotedAmount: 4200,
    currencyCode: 'USD',
    status: 'submitted',
    submittedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now.subtract(const Duration(hours: 3)),
    applicantDisplayName: displayName,
    applicantProfessionName: professionName,
    applicantProfessionSlug: professionSlug,
  );
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpInbox(
  WidgetTester tester, {
  required JobProvider jobs,
  required HireProvider hires,
  required OnboardingProvider onboarding,
  required AuthProvider auth,
  required GoRouter router,
  PortfolioRepository? portfolios,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<JobProvider>.value(value: jobs),
        ChangeNotifierProvider<HireProvider>.value(value: hires),
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<PortfolioRepository>.value(
          value: portfolios ?? _StubPortfolioRepository(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/dashboard/jobs',
  routes: <RouteBase>[
    GoRoute(
      path: '/dashboard/jobs',
      builder: (BuildContext context, GoRouterState state) =>
          const MyJobsScreen(),
    ),
    GoRoute(
      path: '/dashboard/applications',
      builder: (BuildContext context, GoRouterState state) =>
          MyApplicationsScreen(
        initialJobId: state.uri.queryParameters['job'],
      ),
    ),
    GoRoute(
      path: '/dashboard/messages',
      builder: (BuildContext context, GoRouterState state) =>
          const Text('messages'),
    ),
    GoRoute(
      path: '/p/:slug/:id',
      builder: (BuildContext context, GoRouterState state) => Scaffold(
        body: Center(
          child: Text(
            'profile-${state.pathParameters['id']}-'
            '${state.pathParameters['slug']}',
          ),
        ),
      ),
    ),
  ],
);

void main() {
  group('Applicant identity (Phase 4)', () {
    testWidgets('approved applicant shows display name, headline, initials',
        (tester) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-1', 'Office Renovation')],
          <String, List<JobApplication>>{
            'job-1': <JobApplication>[
              _app('app-1', 'job-1', 'pro-1', 'Electrical note.'),
            ],
          },
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final OnboardingProvider onboarding = OnboardingProvider(
        service: _StubOnboardingService(),
      );
      await onboarding.loadProgress('entity-1');
      final AuthProvider auth = AuthProvider(service: FakeAuthService());
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      final GoRouter router = _router();
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await _pumpInbox(
        tester,
        jobs: jobs,
        hires: hires,
        onboarding: onboarding,
        auth: auth,
        router: router,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('1 Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Real identity from the applicant's public profile — never the raw id.
      expect(find.text('Adaeze Okafor'), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('AO'), findsOneWidget);
      expect(find.textContaining('Applicant ·'), findsNothing);
      expect(find.textContaining('pro-1'), findsNothing);
    });

    testWidgets('gated applicant falls back gracefully, profile id correct',
        (tester) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-2', 'Plumbing Fix')],
          <String, List<JobApplication>>{
            'job-2': <JobApplication>[
              _app('app-2', 'job-2', 'pro-2', 'Pipes note.'),
            ],
          },
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final OnboardingProvider onboarding = OnboardingProvider(
        service: _StubOnboardingService(),
      );
      await onboarding.loadProgress('entity-1');
      final AuthProvider auth = AuthProvider(service: FakeAuthService());
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      final GoRouter router = _router();
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await _pumpInbox(
        tester,
        jobs: jobs,
        hires: hires,
        onboarding: onboarding,
        auth: auth,
        router: router,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('1 Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Graceful fallback: generic label, no raw identifier as a name.
      expect(find.text('Applicant'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);
      expect(find.textContaining('Applicant ·'), findsNothing);
      expect(find.textContaining('pro-2'), findsNothing);

      // The review view opens from the card; View Profile there still
      // targets the applicant's own entity id with the cosmetic fallback
      // slug (the id was already correct in Phase 1).
      await tester.tap(find.text('Applicant'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Proposal'), findsOneWidget);
      await tester.ensureVisible(find.text('View Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('profile-pro-2-professional'), findsOneWidget);
    });

    testWidgets('view profile uses the real profession slug when known',
        (tester) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-1', 'Office Renovation')],
          <String, List<JobApplication>>{
            'job-1': <JobApplication>[
              _app('app-1', 'job-1', 'pro-1', 'Electrical note.'),
            ],
          },
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final OnboardingProvider onboarding = OnboardingProvider(
        service: _StubOnboardingService(),
      );
      await onboarding.loadProgress('entity-1');
      final AuthProvider auth = AuthProvider(service: FakeAuthService());
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      final GoRouter router = _router();
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await _pumpInbox(
        tester,
        jobs: jobs,
        hires: hires,
        onboarding: onboarding,
        auth: auth,
        router: router,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('1 Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Adaeze Okafor'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('View Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('profile-pro-1-electrician'), findsOneWidget);
    });

    testWidgets('snapshot row renders with zero profile RPCs', (tester) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-9', 'Pipe Replacement')],
          <String, List<JobApplication>>{
            'job-9': <JobApplication>[
              _appSnap('app-9', 'job-9', 'pro-9', 'Pipes note.'),
            ],
          },
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final OnboardingProvider onboarding = OnboardingProvider(
        service: _StubOnboardingService(),
      );
      await onboarding.loadProgress('entity-1');
      final AuthProvider auth = AuthProvider(service: FakeAuthService());
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      final GoRouter router = _router();
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await _pumpInbox(
        tester,
        jobs: jobs,
        hires: hires,
        onboarding: onboarding,
        auth: auth,
        router: router,
        portfolios: _NoRpcPortfolioRepository(),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('1 Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Snapshot identity, no RPC issued (the stub throws on any call).
      expect(find.text('Chidi Eze'), findsOneWidget);
      expect(find.text('Plumber'), findsOneWidget);
      expect(find.text('CE'), findsOneWidget);

      await tester.tap(find.text('Chidi Eze'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('View Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('profile-pro-9-plumber'), findsOneWidget);
    });
  });
}

