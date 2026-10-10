import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
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

JobApplication _app(String id, String jobId, String note) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: id,
    jobId: jobId,
    professionalEntityId: 'pro-1',
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

void main() {
  group('My Jobs card actions', () {
    testWidgets('actions share one height with content widths', (
      tester,
    ) async {
      for (final double width in <double>[320, 390, 480, 1280]) {
        final JobProvider jobs = JobProvider(
          service: _StubJobService(<Job>[
            _job('job-1', 'Senior React Developer', apps: 12),
          ]),
        );
        final HireProvider hires = HireProvider(
          service: _StubHireService(),
        );
        await pumpScreen(
          tester,
          MyJobsScreen(key: ValueKey(width)),
          width: width,
          height: 844,
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<JobProvider>.value(value: jobs),
            ChangeNotifierProvider<HireProvider>.value(value: hires),
          ],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Overflow at ${width.toInt()}px');

        // Same height across the trio…
        final double primaryHeight = tester.getSize(
          find.ancestor(
            of: find.text('12 Applicants'),
            matching: find.byType(ElevatedButton),
          ),
        ).height;
        for (final String label in <String>['Message', 'Close']) {
          final Finder wrapper = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (Widget w) => w is SizedBox && w.height == 48,
            ),
          );
          expect(wrapper, findsOneWidget, reason: '$label at $width');
        }
        expect(primaryHeight, 48);

        // …content-based widths (longer label wins)…
        final double appsWidth = tester.getSize(
          find.ancestor(
            of: find.text('12 Applicants'),
            matching: find.byType(ElevatedButton),
          ),
        ).width;
        final double chatWidth = tester.getSize(
          find
              .ancestor(
                of: find.text('Message'),
                matching: find.byWidgetPredicate(
                  (Widget w) => w is SizedBox && w.height == 48,
                ),
              )
              .first,
        ).width;
        expect(appsWidth, greaterThan(chatWidth));

        // …and one shared row where the single-column card fits them
        // (599px here; narrower cards and multi-column grids wrap by
        // design, keeping equal heights per run).
        if (width == 599) {
          final double appsTop = tester.getTopLeft(
            find.text('12 Applicants'),
          ).dy;
          final double chatTop = tester.getTopLeft(find.text('Message')).dy;
          final double closeTop = tester.getTopLeft(find.text('Close')).dy;
          expect((appsTop - chatTop).abs(), lessThanOrEqualTo(8));
          expect((appsTop - closeTop).abs(), lessThanOrEqualTo(8));
        }

        // Location lives in the top chips only; the body shows the
        // two-line description plus a Read more link per card.
        expect(find.text('Remote'), findsOneWidget);
        expect(
          find.text('Build and ship Hivorr web experiences for our team.'),
          findsOneWidget,
        );
        expect(find.text('Read more'), findsOneWidget);
        final Finder description = find.text(
          'Build and ship Hivorr web experiences for our team.',
        );
        expect(tester.widget<Text>(description).maxLines, 2);
        jobs.dispose();
        hires.dispose();
      }
    });

    testWidgets('status tabs stay single-line in a scrolling row', (
      tester,
    ) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-1', 'Senior React Developer')],
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
      });
      await pumpScreen(
        tester,
        const MyJobsScreen(),
        width: 320,
        height: 844,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final String tab in <String>[
        'All Jobs',
        'Open',
        'In Progress',
        'Completed',
        'Cancelled',
        'Disputed',
      ]) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('Applicants opens the inbox preselected to the job', (
      tester,
    ) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[
            _job('job-1', 'Senior React Developer', apps: 1),
            _job('job-2', 'Office Renovation', apps: 1),
          ],
          <String, List<JobApplication>>{
            'job-1': <JobApplication>[
              _app('app-1', 'job-1', 'React note.'),
            ],
            'job-2': <JobApplication>[
              _app('app-2', 'job-2', 'Electrical note.'),
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
      final GoRouter router = GoRouter(
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
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<JobProvider>.value(value: jobs),
            ChangeNotifierProvider<HireProvider>.value(value: hires),
            ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Second job's applicants button → inbox preselected to that job.
      await tester.tap(find.text('1 Applicants').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Select Job'), findsOneWidget);
      expect(find.text('Office Renovation'), findsWidgets);
      expect(find.textContaining('Electrical note.'), findsOneWidget);
      expect(find.textContaining('React note.'), findsNothing);
    });

    testWidgets('Read more opens the job detail for that job', (
      tester,
    ) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-1', 'Senior React Developer')],
        ),
      );
      final HireProvider hires = HireProvider(service: _StubHireService());
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      final GoRouter router = GoRouter(
        initialLocation: '/dashboard/jobs',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard/jobs',
            builder: (BuildContext context, GoRouterState state) =>
                const MyJobsScreen(),
          ),
          GoRoute(
            path: '/dashboard/jobs/:id',
            builder: (BuildContext context, GoRouterState state) =>
                Text('detail-${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
        router.dispose();
        jobs.dispose();
        hires.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<JobProvider>.value(value: jobs),
            ChangeNotifierProvider<HireProvider>.value(value: hires),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('detail-job-1'), findsOneWidget);
    });

    testWidgets('Message still routes to Messages', (tester) async {
      final JobProvider jobs = JobProvider(
        service: _StubJobService(
          <Job>[_job('job-1', 'Senior React Developer')],
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
      final GoRouter router = GoRouter(
        initialLocation: '/dashboard/jobs',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard/jobs',
            builder: (BuildContext context, GoRouterState state) =>
                const MyJobsScreen(),
          ),
          GoRoute(
            path: '/dashboard/messages',
            builder: (BuildContext context, GoRouterState state) =>
                const Text('messages'),
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
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<JobProvider>.value(value: jobs),
            ChangeNotifierProvider<HireProvider>.value(value: hires),
            ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('messages'), findsOneWidget);
    });
  });
}
