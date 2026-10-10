import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_overview_screen.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
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
  }) async => JobPage(jobs: _posted(), hasMore: false, nextCursor: null);

  static List<Job> _posted() {
    final DateTime now = DateTime.now();
    Job job(
      String id,
      String title,
      String description,
      double budget,
      int apps,
    ) => Job(
      id: id,
      clientEntityId: 'entity-1',
      title: title,
      description: description,
      budgetMin: budget,
      budgetMax: budget,
      currencyCode: 'USD',
      location: 'Remote',
      status: 'open',
      applicationsCount: apps,
      postedAt: now.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
    );
    return <Job>[
      job(
        'job-1',
        'Senior React Developer Needed Urgently For Fintech',
        'Build and ship responsive Hivorr web experiences with React, '
            'TypeScript and Node.js. You will own features end to end, '
            'from Figma to production deploys and performance tuning.',
        3500,
        12,
      ),
      job('job-2', 'Short', 'Tiny desc here.', 800, 1),
    ];
  }

  @override
  Future<ApplicationPage> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) async =>
      const ApplicationPage(applications: [], hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

List<SingleChildWidget> _providers({
  required JobProvider jobs,
  required HireProvider hires,
  required OnboardingProvider onboarding,
  required AuthProvider auth,
}) => <SingleChildWidget>[
  ChangeNotifierProvider<JobProvider>.value(value: jobs),
  ChangeNotifierProvider<HireProvider>.value(value: hires),
  ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
  ChangeNotifierProvider<AuthProvider>.value(value: auth),
];

void main() {
  group('Client active job card', () {
    testWidgets('amount pins right, location deduped, preview + read more',
        (tester) async {
      for (final double width in <double>[320, 360, 390, 414, 599, 1280]) {
        final JobProvider jobs = JobProvider(service: _StubJobService());
        final HireProvider hires = HireProvider(service: _StubHireService());
        final OnboardingProvider onboarding = OnboardingProvider(
          service: _StubOnboardingService(),
        );
        await onboarding.loadProgress('entity-1');
        final AuthProvider auth = AuthProvider(service: FakeAuthService());
        await pumpScreen(
          tester,
          DashboardOverviewScreen(key: ValueKey(width)),
          width: width,
          height: 900,
          providers: _providers(
            jobs: jobs,
            hires: hires,
            onboarding: onboarding,
            auth: auth,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Overflow at ${width.toInt()}px');

        // Data intact.
        expect(find.text(r'$3,500'), findsOneWidget);
        expect(find.text('12 applied'), findsOneWidget);

        // Location shown once (chip only), description previewed in 2 lines.
        expect(find.text('Remote'), findsWidgets);
        expect(find.text('Read more'), findsWidgets);
        final Finder preview = find.textContaining('responsive Hivorr web');
        expect(preview, findsOneWidget);
        expect(tester.widget<Text>(preview).maxLines, 2);

        // Amount + count hug the card's right edge (card padding + glyph
        // bearing tolerance).
        final Finder card = find.ancestor(
          of: find.text(r'$3,500'),
          matching: find.byType(HivorrCard),
        );
        final Rect cardBox = tester.getRect(card.first);
        final Rect budgetBox = tester.getRect(find.text(r'$3,500'));
        final Rect appliedBox = tester.getRect(find.text('12 applied'));
        expect(cardBox.right - budgetBox.right, lessThanOrEqualTo(20));
        expect(cardBox.right - appliedBox.right, lessThanOrEqualTo(20));
        expect(budgetBox.right, greaterThan(cardBox.center.dx));
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      }
    });

    testWidgets('read more opens the job detail for that job', (
      tester,
    ) async {
      final JobProvider jobs = JobProvider(service: _StubJobService());
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
      final GoRouter router = GoRouter(
        initialLocation: '/dashboard',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard',
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardOverviewScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'jobs/:id',
                builder: (BuildContext context, GoRouterState state) => Scaffold(
                  body: Center(
                    child: Text(
                      'detail-${state.pathParameters['id']}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(
            jobs: jobs,
            hires: hires,
            onboarding: onboarding,
            auth: auth,
          ),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Read more').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('detail-job-1'), findsOneWidget);
    });

    testWidgets('applicants button opens the inbox for that job, not detail',
        (tester) async {
      final JobProvider jobs = JobProvider(service: _StubJobService());
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
      final GoRouter router = GoRouter(
        initialLocation: '/dashboard',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard',
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardOverviewScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'jobs/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    Scaffold(
                  body: Center(
                    child: Text(
                      'detail-${state.pathParameters['id']}',
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: 'applications',
                builder: (BuildContext context, GoRouterState state) =>
                    MyApplicationsScreen(
                  initialJobId: state.uri.queryParameters['job'],
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: _providers(
            jobs: jobs,
            hires: hires,
            onboarding: onboarding,
            auth: auth,
          ),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Job-specific Applicants button → inbox preselected to job-1, with the
      // authoritative count in the header — not the job detail screen.
      await tester.tap(find.text('12 Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('detail-job-1'), findsNothing);
      expect(find.text('Select Job'), findsOneWidget);
      expect(find.textContaining('12 applications'), findsOneWidget);
      expect(
        find.text('Senior React Developer Needed Urgently For Fintech'),
        findsWidgets,
      );
    });
  });
}
