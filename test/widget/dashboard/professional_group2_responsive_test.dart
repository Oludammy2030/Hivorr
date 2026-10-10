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
import 'package:hivorr/systems/dashboard/screens/hires_screen.dart';
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

/// Phase 4 Group 2 locks: professional My Jobs (phase tabs + Active/Applied/
/// Completed content) and My Applications (filter chips + application rows).
/// Covers the Group 2 fixes (MobileSafeBody contract, list clearance) and
/// guards the reference layouts at narrow widths. Neither screen owns text
/// inputs, so no keyboard test applies.
class _Group2JobService implements JobService {
  _Group2JobService(this.jobs, this.applications);

  final List<Job> jobs;
  final List<JobApplication> applications;

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
  }) async => ApplicationPage(
    applications: status == null
        ? applications
        : applications
              .where((JobApplication app) => app.status == status)
              .toList(growable: false),
    hasMore: false,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Group2HireService implements HireService {
  _Group2HireService(this.hires);

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

JobApplication _application({required String id, required String status}) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: id,
    jobId: 'job-1',
    professionalEntityId: 'entity-1',
    clientEntityId: 'client-1',
    coverNote: 'Five years of React and TypeScript experience.',
    quotedAmount: 2500,
    currencyCode: 'USD',
    status: status,
    jobTitle: 'Senior React Developer',
    submittedAt: now.subtract(const Duration(days: 1)),
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now,
  );
}

Future<List<SingleChildWidget>> _group2Providers() async {
  final DateTime now = DateTime.now();
  final Job seededJob = Job(
    id: 'job-1',
    clientEntityId: 'client-1',
    title: 'Senior React Developer',
    description: 'Build fintech platforms for African startups.',
    budgetMin: 3000,
    budgetMax: 5000,
    currencyCode: 'USD',
    location: 'Remote',
    status: 'open',
    applicationsCount: 12,
    postedAt: now.subtract(const Duration(hours: 3)),
    createdAt: now.subtract(const Duration(hours: 3)),
    updatedAt: now,
  );
  final JobProvider jobs = JobProvider(
    service: _Group2JobService(
      <Job>[seededJob],
      <JobApplication>[
        _application(id: 'app-1', status: 'submitted'),
        _application(id: 'app-2', status: 'accepted'),
      ],
    ),
  );
  final HireProvider hires = HireProvider(
    service: _Group2HireService(<Hire>[
      Hire(
        id: 'hire-1',
        jobId: 'job-1',
        applicationId: 'app-2',
        clientEntityId: 'client-1',
        professionalEntityId: 'entity-1',
        status: 'active',
        hiredAt: now.subtract(const Duration(days: 1)),
        jobTitle: 'Senior React Developer',
      ),
      Hire(
        id: 'hire-2',
        jobId: 'job-1',
        applicationId: 'app-3',
        clientEntityId: 'client-1',
        professionalEntityId: 'entity-1',
        status: 'completed',
        hiredAt: now.subtract(const Duration(days: 30)),
        jobTitle: 'Solar Panel Installation',
      ),
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
  group('Group 2 — professional My Jobs', () {
    for (final double width in <double>[320, 390]) {
      testWidgets('phases render without overflow at ${width.toInt()}dp', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const HiresScreen(role: 'professional'),
          width: width,
          providers: await _group2Providers(),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('My Jobs'), findsWidgets);
        expect(find.text('Active'), findsOneWidget);
        // Active phase reference cards with card actions.
        expect(find.text('Chat'), findsOneWidget);

        await tester.ensureVisible(find.text('Applied'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Applied'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Accepted application row exposes Contact Employer.
        expect(find.text('Contact Employer'), findsOneWidget);

        await tester.ensureVisible(find.text('Completed'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Paid'), findsOneWidget);
      });
    }

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _group2Providers();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const HiresScreen(role: 'professional'),
        ),
      );
    });
  });

  group('Group 2 — My Applications', () {
    for (final double width in <double>[320, 360, 390, 430]) {
      testWidgets('no overflow at ${width.toInt()}dp', (tester) async {
        await pumpScreen(
          tester,
          const MyApplicationsScreen(),
          width: width,
          providers: await _group2Providers(),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at ${width.toInt()}dp',
        );
        expect(find.text('My Applications'), findsOneWidget);
      });
    }

    testWidgets('respects bottom safe area', (tester) async {
      final List<SingleChildWidget> providers = await _group2Providers();
      await expectSafeAreaRespected(
        tester,
        () => MultiProvider(
          providers: providers,
          child: const MyApplicationsScreen(),
        ),
      );
    });
  });
}
