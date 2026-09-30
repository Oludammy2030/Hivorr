import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/widget_harness.dart';

/// Scripted [JobService]: serves the discovery list plus the professional's
/// own applications. `submitApplication` records the row (one per
/// job+professional, mirroring the server constraint) and throws a
/// `conflict` for duplicates or [conflictJobIds] (simulated server race).
class _StubDiscoveryService implements JobService {
  _StubDiscoveryService(this.jobs, {Set<String>? conflictJobIds})
    : _mine = <JobApplication>[],
      conflictJobIds = <String>{...?conflictJobIds};

  final List<Job> jobs;

  /// Job ids whose submit always conflicts (simulated duplicate race).
  final Set<String> conflictJobIds;

  final List<JobApplication> _mine;

  /// Recorded submissions in call order.
  final List<SubmittedApplication> submissions = <SubmittedApplication>[];

  /// Seeds a pre-existing own application (e.g. applied in a prior visit).
  void seedApplication(JobApplication application) => _mine.add(application);

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async {
    if (search != null && search.isNotEmpty) {
      final String q = search.toLowerCase();
      return JobPage(
        jobs: jobs
            .where(
              (Job job) =>
                  job.title.toLowerCase().contains(q) ||
                  job.description.toLowerCase().contains(q),
            )
            .toList(growable: false),
        hasMore: false,
        nextCursor: null,
      );
    }
    return JobPage(jobs: jobs, hasMore: false, nextCursor: null);
  }

  @override
  Future<ApplicationPage> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) async => ApplicationPage(
    applications: List<JobApplication>.unmodifiable(_mine),
    hasMore: false,
    nextCursor: null,
  );

  @override
  Future<JobApplication> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  }) async {
    if (conflictJobIds.contains(jobId) ||
        _mine.any((JobApplication app) => app.jobId == jobId)) {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'This application already exists.',
        code: 'PLT005',
      );
    }
    submissions.add(
      SubmittedApplication(
        jobId: jobId,
        coverNote: coverNote,
        quotedAmount: quotedAmount,
        currencyCode: currencyCode,
      ),
    );
    final DateTime now = DateTime.now();
    final JobApplication application = JobApplication(
      id: 'app-$jobId',
      jobId: jobId,
      professionalEntityId: 'entity-1',
      clientEntityId: 'client-1',
      coverNote: coverNote,
      quotedAmount: quotedAmount,
      currencyCode: currencyCode,
      status: 'submitted',
      submittedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    _mine.add(application);
    return application;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class SubmittedApplication {
  const SubmittedApplication({
    required this.jobId,
    required this.coverNote,
    required this.quotedAmount,
    required this.currencyCode,
  });

  final String jobId;
  final String coverNote;
  final double? quotedAmount;
  final String currencyCode;
}

Job _discoveryJob({
  required String id,
  required String title,
  required int applicationsCount,
  double? budget,
  String location = 'Remote',
  required Duration postedAgo,
  String? professionId,
}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'client-1',
    professionId: professionId,
    title: title,
    description: 'Build and ship Hivorr web experiences.',
    budgetMin: budget,
    budgetMax: budget,
    currencyCode: 'USD',
    location: location,
    status: 'open',
    applicationsCount: applicationsCount,
    postedAt: now.subtract(postedAgo),
    createdAt: now.subtract(postedAgo),
    updatedAt: now,
  );
}

JobApplication _seedApp({required String jobId}) {
  final DateTime now = DateTime.now();
  return JobApplication(
    id: 'app-$jobId-seeded',
    jobId: jobId,
    professionalEntityId: 'entity-1',
    clientEntityId: 'client-1',
    coverNote: 'Seeded cover note proving prior interest in this role.',
    currencyCode: 'USD',
    status: 'submitted',
    submittedAt: now.subtract(const Duration(days: 1)),
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now.subtract(const Duration(days: 1)),
  );
}

void main() {
  group('Find Work (reference layout)', () {
    late _StubDiscoveryService service;
    late JobProvider jobs;
    late FakeAuthProvider auth;

    List<Job> seedJobs() => <Job>[
      _discoveryJob(
        id: 'job-1',
        title: 'Senior React Developer',
        applicationsCount: 12,
        budget: 3500,
        postedAgo: const Duration(hours: 2),
        professionId: 'development',
      ),
      _discoveryJob(
        id: 'job-2',
        title: 'Brand Identity Design Package',
        applicationsCount: 23,
        budget: 800,
        postedAgo: const Duration(days: 1),
        professionId: 'design',
      ),
      _discoveryJob(
        id: 'job-3',
        title: 'Home Plumbing Emergency Fix',
        applicationsCount: 3,
        budget: 150,
        location: 'Nairobi, KE',
        postedAgo: const Duration(minutes: 30),
        professionId: 'plumbing',
      ),
      _discoveryJob(
        id: 'job-4',
        title: 'Solar Panel Installation — 20 Units',
        applicationsCount: 9,
        budget: 4200,
        location: 'Abuja, NG',
        postedAgo: const Duration(days: 3),
        professionId: 'energy',
      ),
    ];

    setUp(() {
      service = _StubDiscoveryService(seedJobs());
      // job-1 was applied in a prior visit: its card must render Applied.
      service.seedApplication(_seedApp(jobId: 'job-1'));
      jobs = JobProvider(service: service);
      auth = FakeAuthProvider(initialStatus: AuthStatus.authenticated)
        ..sessionOverride = const AuthSession(
          entityId: 'entity-1',
          email: 'amara.diallo@example.com',
          firstName: 'Amara',
          lastName: 'Diallo',
        );
      addTearDown(() {
        jobs.dispose();
        auth.dispose();
      });
    });

    Future<void> pumpFindWork(
      WidgetTester tester, {
      double width = 1440,
      double height = 900,
    }) {
      return pumpScreen(
        tester,
        const OpportunitiesScreen(),
        width: width,
        height: height,
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
      );
    }

    testWidgets('desktop renders the reference Find Work layout', (
      WidgetTester tester,
    ) async {
      await pumpFindWork(tester);
      await tester.pumpAndSettle();

      // Reference top bar with dynamic initials (Amara Diallo → AD).
      expect(find.text('Find Work'), findsWidgets);
      expect(find.text('AD'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);

      // Search header + availability subtitle.
      expect(
        find.text('Search jobs by title, company, or skill…'),
        findsOneWidget,
      );
      expect(find.text('Filter'), findsOneWidget);
      expect(
        find.text('4 opportunities available · Matched to your skills'),
        findsOneWidget,
      );

      // Reference cards: pills, price, applied count, meta, actions.
      expect(find.text('Senior React Developer'), findsOneWidget);
      expect(find.text('Solar Panel Installation — 20 Units'), findsOneWidget);
      expect(find.text('Urgent'), findsNWidgets(3));
      expect(find.text('12 applied'), findsOneWidget);
      // job-1 carries the seeded own application: Applied, not Apply Now.
      expect(find.text('Applied!'), findsOneWidget);
      expect(find.text('Apply Now'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('apply flow submits and marks only that card Applied', (
      WidgetTester tester,
    ) async {
      await pumpFindWork(tester);
      await tester.pumpAndSettle();

      // First Apply Now belongs to job-2 (job-1 already shows Applied).
      await tester.tap(find.text('Apply Now').first);
      await tester.pumpAndSettle();
      expect(find.text('Your Proposed Rate'), findsOneWidget);
      expect(find.text('Cover Letter'), findsOneWidget);
      expect(find.text('Relevant Portfolio Link (optional)'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        r'$2,500 fixed',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'I have five years of React and TypeScript experience '
        'building fintech platforms for African startups.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'github.com/amara',
      );
      await tester.tap(find.text('Submit Application').last);
      await tester.pumpAndSettle();

      // One submission against job-2 with the parsed quote in the job
      // currency and the portfolio link folded into the stored note, so
      // the client sees it in Applications.
      expect(service.submissions, hasLength(1));
      final SubmittedApplication submitted = service.submissions.single;
      expect(submitted.jobId, 'job-2');
      expect(submitted.quotedAmount, 2500);
      expect(submitted.currencyCode, 'USD');
      expect(submitted.coverNote, contains('Portfolio: github.com/amara'));

      // Overlay closed; only job-2 joined job-1 in the Applied state.
      expect(find.text('Your Proposed Rate'), findsNothing);
      expect(find.text('Applied!'), findsNWidgets(2));
      expect(find.text('Apply Now'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('short cover letter blocks submission with an error', (
      WidgetTester tester,
    ) async {
      await pumpFindWork(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Now').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Too short',
      );
      await tester.tap(find.text('Submit Application').last);
      await tester.pump();

      expect(
        find.text('Cover letter must be 20 to 2000 characters.'),
        findsOneWidget,
      );
      expect(service.submissions, isEmpty);
      // Dialog stays open for correction.
      expect(find.text('Your Proposed Rate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('server conflict surfaces an error and keeps Applied honest', (
      WidgetTester tester,
    ) async {
      service.conflictJobIds.add('job-3');
      await pumpFindWork(tester);
      await tester.pumpAndSettle();

      // job-3 is the second Apply Now (job-1 shows Applied).
      await tester.tap(find.text('Apply Now').at(1));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'I am a licensed plumber available today with my own tools '
        'and transport across Nairobi.',
      );
      await tester.tap(find.text('Submit Application').last);
      await tester.pump();
      await tester.pump();

      // No row exists for job-3, so the conflict is a real error: the
      // dialog stays open and the card keeps Apply Now.
      expect(find.text('This application already exists.'), findsOneWidget);
      expect(find.text('Your Proposed Rate'), findsOneWidget);
      expect(service.submissions, isEmpty);
      expect(find.text('Applied!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter sheet sorts the loaded page by budget', (
      WidgetTester tester,
    ) async {
      await pumpFindWork(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Highest budget'), findsOneWidget);

      await tester.tap(find.text('Highest budget'));
      await tester.pump();
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      // Highest budget first, lowest last.
      final double top = tester
          .getTopLeft(find.text('Solar Panel Installation — 20 Units'))
          .dy;
      final double bottom = tester
          .getTopLeft(find.text('Home Plumbing Emergency Fix'))
          .dy;
      expect(top, lessThan(bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile stacks the Find Work layout without overflow', (
      WidgetTester tester,
    ) async {
      await pumpFindWork(tester, width: 390, height: 844);
      await tester.pumpAndSettle();

      expect(find.text('Find Work'), findsWidgets);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Senior React Developer'), findsOneWidget);
      // Single-column grid lazily builds below-the-fold cards; job-1
      // already shows its seeded Applied state.
      expect(find.text('Applied!'), findsOneWidget);
      expect(find.text('Apply Now'), findsAtLeastNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
