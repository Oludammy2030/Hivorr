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
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/screens/dashboard_overview_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/widget_harness.dart';

/// Scripted [JobService]: serves the posted list and per-job applications,
// everything else is unimplemented (the overview never touches it).
class _StubJobService implements JobService {
  _StubJobService(this.posted, [this.applicationsByJob = const {}]);

  final List<Job> posted;
  final Map<String, List<JobApplication>> applicationsByJob;

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

/// Scripted [HireService]: serves the client hire list.
class _StubHireService implements HireService {
  _StubHireService(this.hires);

  final List<Hire> hires;

  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => HirePage(hires: hires, hasMore: false, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Scripted [OnboardingService]: resumes a hire-capability position.
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

Job _postedJob({
  required String id,
  required String title,
  required String status,
  required int applicationsCount,
  double? budgetMin,
  double? budgetMax,
  String location = 'Remote',
}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'entity-1',
    title: title,
    description: 'Build and ship Hivorr web experiences.',
    budgetMin: budgetMin,
    budgetMax: budgetMax,
    currencyCode: 'USD',
    location: location,
    status: status,
    applicationsCount: applicationsCount,
    postedAt: now.subtract(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
  );
}

void main() {
  group('Client overview (reference layout)', () {
    late JobProvider jobs;
    late HireProvider hires;
    late OnboardingProvider onboarding;
    late AuthProvider auth;
    late DashboardViewModeProvider viewMode;

    setUp(() async {
      final DateTime now = DateTime.now();
      jobs = JobProvider(
        service: _StubJobService(
          <Job>[
            _postedJob(
              id: 'job-1',
              title: 'Senior React Developer',
              status: 'open',
              applicationsCount: 12,
              budgetMin: 3500,
              budgetMax: 3500,
            ),
            _postedJob(
              id: 'job-2',
              title: 'Mobile App Designer',
              status: 'awarded',
              applicationsCount: 22,
              budgetMax: 8900,
              location: 'Lagos, Nigeria',
            ),
          ],
          <String, List<JobApplication>>{
            'job-1': <JobApplication>[
              JobApplication(
                id: 'app-1',
                jobId: 'job-1',
                professionalEntityId: 'pro-7',
                clientEntityId: 'entity-1',
                coverNote: 'I can build this checkout flow.',
                quotedAmount: 3500,
                currencyCode: 'USD',
                status: 'shortlisted',
                submittedAt: now.subtract(const Duration(hours: 2)),
                createdAt: now.subtract(const Duration(hours: 2)),
                updatedAt: now.subtract(const Duration(hours: 2)),
              ),
            ],
          },
        ),
      );
      hires = HireProvider(
        service: _StubHireService(<Hire>[
          Hire(
            id: 'hire-1',
            jobId: 'job-2',
            applicationId: 'app-9',
            clientEntityId: 'entity-1',
            professionalEntityId: 'pro-1',
            status: 'active',
            hiredAt: DateTime.now().subtract(const Duration(days: 1)),
            effectiveStatus: 'active',
            jobTitle: 'Office Renovation & Electrical',
          ),
        ]),
      );
      onboarding = OnboardingProvider(service: _StubOnboardingService());
      await onboarding.loadProgress('entity-1');
      auth = AuthProvider(service: FakeAuthService());
      viewMode = DashboardViewModeProvider();
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
        onboarding.dispose();
        auth.dispose();
        viewMode.dispose();
      });
    });

    Future<void> pumpOverview(
      WidgetTester tester, {
      double width = 1440,
      double height = 900,
    }) {
      return pumpScreen(
        tester,
        const DashboardOverviewScreen(),
        width: width,
        height: height,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
          ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<DashboardViewModeProvider>.value(
            value: viewMode,
          ),
        ],
      );
    }

    testWidgets('desktop renders the reference client layout', (tester) async {
      await pumpOverview(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Top bar.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);

      // Hero.
      expect(
        find.text(
          'You have 34 new applications across your active jobs',
          findRichText: true,
        ),
        findsOneWidget,
      );

      // Quick actions.
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.text('View Applications'), findsOneWidget);
      expect(find.text('Message Hires'), findsOneWidget);

      // Active jobs (full open-first list).
      expect(find.text('Active Jobs'), findsOneWidget);
      expect(find.text('Manage all'), findsOneWidget);
      expect(find.text('Senior React Developer'), findsWidgets);
      expect(find.text('Mobile App Designer'), findsOneWidget);
      expect(find.text('12 Applicants'), findsOneWidget);
      expect(find.text('Message'), findsWidgets);
      expect(find.text(r'$3,500'), findsOneWidget);
      expect(find.text('12 applied'), findsOneWidget);

      // Right-rail metrics (labels also appear on the hero glass chips).
      expect(find.text('Jobs Posted'), findsWidgets);
      expect(find.text('Active Hires'), findsWidgets);
      expect(find.text('Total Spent'), findsWidgets);
      expect(find.text('Open Apps'), findsOneWidget);
      expect(find.text(r'$8.9K'), findsOneWidget);

      // Mock money rail (reference placeholders — see client_overview_mock).
      expect(find.text('Spending Overview'), findsOneWidget);
      expect(find.text('Monthly budget used'), findsOneWidget);
      expect(find.text(r'$12,400 / $20,000'), findsOneWidget);
      expect(find.text('62% of monthly budget'), findsOneWidget);
      expect(find.text(r'$1,200 held in escrow'), findsOneWidget);
      expect(find.text('Recent Payments'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Payment to Amara Diallo'), findsOneWidget);
      expect(find.text(r'-$3,500'), findsOneWidget);
      expect(find.text('Escrow: Office Renovation'), findsOneWidget);
      expect(find.text(r'$1,200'), findsOneWidget);

      // Recent applications feed.
      expect(find.text('Recent Applications'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('USD 3,500'), findsOneWidget);
      expect(find.text('Shortlisted'), findsOneWidget);
      // Feed date + mock payment date both render as `Today, …`.
      expect(find.textContaining('Today,'), findsWidgets);

      // Current hires rail card.
      expect(find.text('Current Hires'), findsOneWidget);
      expect(find.text('Office Renovation & Electrical'), findsOneWidget);

      // Shared sections are preserved.
      expect(find.text('Money'), findsOneWidget);
    });

    testWidgets('mobile stacks the client layout without the desktop top bar', (
      tester,
    ) async {
      await pumpOverview(tester, width: 390, height: 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Senior React Developer'), findsWidgets);
      expect(find.text('Recent Applications'), findsOneWidget);
      expect(find.text('Current Hires'), findsOneWidget);
      expect(find.text('Jobs Posted'), findsWidgets);
      expect(find.text('Money'), findsOneWidget);
    });
  });
}
