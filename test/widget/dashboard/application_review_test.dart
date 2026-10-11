import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
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

const String _longNote =
    'First line of the proposal with approach. '
    'Second line covering timeline and milestones. '
    'Third line about materials and costing breakdown. '
    'Fourth line with warranty and aftercare promise. '
    'Fifth line with availability next week.';

JobApplication _snapApp({
  required String id,
  required String jobId,
  required String proId,
  required String note,
  required String name,
  required String status,
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
    durationDays: 5,
    status: status,
    submittedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now.subtract(const Duration(hours: 3)),
    applicantDisplayName: name,
    applicantProfessionName: 'Plumber',
    applicantProfessionSlug: 'plumber',
  );
}

JobApplication _withStatus(JobApplication app, String status) => JobApplication(
  id: app.id,
  jobId: app.jobId,
  professionalEntityId: app.professionalEntityId,
  clientEntityId: app.clientEntityId,
  coverNote: app.coverNote,
  quotedAmount: app.quotedAmount,
  currencyCode: app.currencyCode,
  durationDays: app.durationDays,
  status: status,
  submittedAt: app.submittedAt,
  decidedAt: app.decidedAt,
  createdAt: app.createdAt,
  updatedAt: DateTime.now(),
  jobTitle: app.jobTitle,
  jobStatus: app.jobStatus,
  applicantDisplayName: app.applicantDisplayName,
  applicantAvatarPath: app.applicantAvatarPath,
  applicantProfessionName: app.applicantProfessionName,
  applicantProfessionSlug: app.applicantProfessionSlug,
);

class _StubJobService implements JobService {
  _StubJobService(this.posted, this.byJob);

  final List<Job> posted;
  final Map<String, JobApplication> byJob;

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
    applications: byJob.values
        .where((JobApplication a) => a.jobId == jobId)
        .toList(growable: false),
    hasMore: false,
    nextCursor: null,
  );

  @override
  Future<JobApplication> shortlistApplication(String applicationId) async {
    final JobApplication updated = _withStatus(
      byJob[applicationId]!,
      'shortlisted',
    );
    byJob[applicationId] = updated;
    return updated;
  }

  @override
  Future<JobApplication> rejectApplication(String applicationId) async {
    final JobApplication updated = _withStatus(
      byJob[applicationId]!,
      'rejected',
    );
    byJob[applicationId] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHireService implements HireService {
  _StubHireService(this.byJob);

  final Map<String, JobApplication> byJob;

  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const HirePage(hires: [], hasMore: false, nextCursor: null);

  @override
  Future<HireAcceptResult> acceptHire(
    String applicationId, {
    String? quotationId,
  }) async {
    final JobApplication app = byJob[applicationId]!;
    byJob[applicationId] = _withStatus(app, 'accepted');
    final DateTime now = DateTime.now();
    return HireAcceptResult(
      hire: Hire(
        id: 'hire-1',
        jobId: app.jobId,
        applicationId: app.id,
        clientEntityId: 'entity-1',
        professionalEntityId: app.professionalEntityId,
        contractId: 'contract-1',
        status: 'pending',
        hiredAt: now,
      ),
      contractId: 'contract-1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Snapshot rows render with zero profile RPCs; the stub fails loudly if
/// the inbox ever asks (all fixtures carry the identity snapshot).
class _NoRpcPortfolioRepository implements PortfolioRepository {
  @override
  Future<PublicProfile?> getPublicProfile(String entityId) =>
      throw StateError('unexpected profile RPC for $entityId');
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

void main() {
  group('Application review (Phase 5)', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late AuthProvider auth;
    late GoRouter router;
    late Size previousPhysical;
    late double previousDpr;

    Future<void> pump(
      WidgetTester tester, {
      required List<Job> posted,
      required Map<String, JobApplication> apps,
    }) async {
      jobs = JobProvider(service: _StubJobService(posted, apps));
      hires = HireProvider(service: _StubHireService(apps));
      onboarding = OnboardingProvider(service: _StubOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = AuthProvider(service: FakeAuthService());
      previousPhysical = tester.view.physicalSize;
      previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      router = GoRouter(
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
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<JobProvider>.value(value: jobs),
            ChangeNotifierProvider<HireProvider>.value(value: hires),
            ChangeNotifierProvider<OnboardingProvider>.value(
              value: onboarding,
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            Provider<PortfolioRepository>.value(
              value: _NoRpcPortfolioRepository(),
            ),
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
      await tester.tap(find.text('1 Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    void tearDownView(WidgetTester tester) {
      tester.view.physicalSize = previousPhysical;
      tester.view.devicePixelRatio = previousDpr;
      router.dispose();
      jobs.dispose();
      hires.dispose();
      onboarding.dispose();
      auth.dispose();
    }

    testWidgets('list is concise; card opens the full review view', (
      tester,
    ) async {
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Pipe Replacement')],
        apps: <String, JobApplication>{
          'app-1': _snapApp(
            id: 'app-1',
            jobId: 'job-1',
            proId: 'pro-1',
            note: _longNote,
            name: 'Chidi Eze',
            status: 'submitted',
          ),
        },
      );
      addTearDown(() => tearDownView(tester));

      // Concise list: identity + preview, no decision actions yet.
      expect(find.text('Shortlist'), findsNothing);
      expect(find.text('Hire'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(
        find.text('Tap to review the full proposal'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.text(_longNote)).maxLines,
        3,
      );

      // Review view: full proposal, submitted details, decision actions.
      await tester.tap(find.text('Chidi Eze'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Proposal'), findsOneWidget);
      expect(tester.widget<Text>(find.text(_longNote)).maxLines, isNull);
      expect(find.text('Proposed price'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Shortlist'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(
        find.text('Tap to review the full proposal'),
        findsNothing,
      );

      // Back returns to the list.
      await tester.tap(find.text('Applicants'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Tap to review the full proposal'),
        findsOneWidget,
      );
    });

    testWidgets('shortlist from the review updates status and persists', (
      tester,
    ) async {
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Pipe Replacement')],
        apps: <String, JobApplication>{
          'app-1': _snapApp(
            id: 'app-1',
            jobId: 'job-1',
            proId: 'pro-1',
            note: _longNote,
            name: 'Chidi Eze',
            status: 'submitted',
          ),
        },
      );
      addTearDown(() => tearDownView(tester));

      await tester.tap(find.text('Chidi Eze'));
      await tester.pumpAndSettle();
      // Actions sit below the full proposal: scroll the review into view.
      await tester.ensureVisible(find.text('Shortlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shortlist'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Application shortlisted.'), findsOneWidget);
      expect(find.text('shortlisted'), findsWidgets);
      // Shortlisted applications offer Hire (single primary), not Shortlist.
      expect(find.text('Shortlist'), findsNothing);
      expect(find.text('Hire'), findsOneWidget);

      await tester.tap(find.text('Applicants'));
      await tester.pumpAndSettle();
      expect(find.text('shortlisted'), findsWidgets);
    });

    testWidgets('reject confirms first and only rejects on confirm', (
      tester,
    ) async {
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Pipe Replacement')],
        apps: <String, JobApplication>{
          'app-1': _snapApp(
            id: 'app-1',
            jobId: 'job-1',
            proId: 'pro-1',
            note: _longNote,
            name: 'Chidi Eze',
            status: 'submitted',
          ),
        },
      );
      addTearDown(() => tearDownView(tester));

      await tester.tap(find.text('Chidi Eze'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Reject application?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Keep'));
      await tester.pumpAndSettle();
      expect(find.text('submitted'), findsWidgets);
      expect(find.text('Application rejected.'), findsNothing);

      await tester.ensureVisible(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reject').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Application rejected.'), findsOneWidget);
      expect(find.text('rejected'), findsWidgets);
    });

    testWidgets('hire from the review marks the application hired', (
      tester,
    ) async {
      await pump(
        tester,
        posted: <Job>[_job('job-1', 'Pipe Replacement')],
        apps: <String, JobApplication>{
          'app-2': _snapApp(
            id: 'app-2',
            jobId: 'job-1',
            proId: 'pro-2',
            note: _longNote,
            name: 'Adaeze Okafor',
            status: 'shortlisted',
          ),
        },
      );
      addTearDown(() => tearDownView(tester));

      await tester.tap(find.text('Adaeze Okafor'));
      await tester.pumpAndSettle();
      expect(find.text('Hire'), findsOneWidget);

      await tester.ensureVisible(find.text('Hire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hire'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Professional hired.'), findsOneWidget);
      expect(find.text('Hired'), findsOneWidget);
    });
  });
}
