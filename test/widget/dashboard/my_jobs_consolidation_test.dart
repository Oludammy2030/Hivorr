import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/harnesses/widget_harness.dart';

/// Scripted [JobService]: serves the posted list; cancel flips the job to
/// `cancelled` so the Cancelled tab reflects the transition.
class _FakeJobService implements JobService {
  _FakeJobService(this.posted);

  final List<Job> posted;

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => JobPage(jobs: posted, hasMore: false, nextCursor: null);

  @override
  Future<Job> cancelJob(String jobId, {String? reason}) async {
    final int i = posted.indexWhere((Job j) => j.id == jobId);
    final Job updated = _withStatus(posted[i], 'cancelled');
    posted[i] = updated;
    return updated;
  }

  Job _withStatus(Job job, String status) => Job(
    id: job.id,
    clientEntityId: job.clientEntityId,
    professionId: job.professionId,
    industryId: job.industryId,
    title: job.title,
    description: job.description,
    budgetMin: job.budgetMin,
    budgetMax: job.budgetMax,
    currencyCode: job.currencyCode,
    location: job.location,
    status: status,
    applicationsCount: job.applicationsCount,
    awardedApplicationId: job.awardedApplicationId,
    postedAt: job.postedAt,
    awardedAt: job.awardedAt,
    completedAt: job.completedAt,
    cancelledAt: job.cancelledAt,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Scripted [HireService]: serves the client hire list; cancel/complete
/// record the call and flip the stored hire status.
class _FakeHireService implements HireService {
  _FakeHireService(this.hires);

  final List<Hire> hires;
  final List<String> cancelledIds = <String>[];
  final List<String> completedIds = <String>[];

  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => HirePage(hires: hires, hasMore: false, nextCursor: null);

  @override
  Future<Hire> cancelHire(String hireId, {String? reason}) async {
    cancelledIds.add(hireId);
    final int i = hires.indexWhere((Hire h) => h.id == hireId);
    final Hire updated = _withStatus(hires[i], 'cancelled');
    hires[i] = updated;
    return updated;
  }

  @override
  Future<Hire> completeHire(String hireId) async {
    completedIds.add(hireId);
    final int i = hires.indexWhere((Hire h) => h.id == hireId);
    final Hire updated = _withStatus(hires[i], 'completed');
    hires[i] = updated;
    return updated;
  }

  Hire _withStatus(Hire hire, String status) => Hire(
    id: hire.id,
    jobId: hire.jobId,
    applicationId: hire.applicationId,
    quotationId: hire.quotationId,
    clientEntityId: hire.clientEntityId,
    professionalEntityId: hire.professionalEntityId,
    contractId: hire.contractId,
    status: status,
    hiredAt: hire.hiredAt,
    completedAt: hire.completedAt,
    cancelledAt: hire.cancelledAt,
    jobTitle: hire.jobTitle,
    jobStatus: hire.jobStatus,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Job _job({
  required String id,
  required String title,
  required String status,
}) {
  final DateTime now = DateTime.now();
  return Job(
    id: id,
    clientEntityId: 'entity-1',
    title: title,
    description: 'Build and ship Hivorr web experiences for our team.',
    budgetMax: 2000,
    currencyCode: 'USD',
    location: 'Remote',
    status: status,
    applicationsCount: 3,
    postedAt: now.subtract(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
  );
}

Hire _hire({
  required String id,
  required String jobId,
  required String status,
  String? contractId,
}) => Hire(
  id: id,
  jobId: jobId,
  applicationId: 'app-$id',
  clientEntityId: 'entity-1',
  professionalEntityId: 'pro-1',
  contractId: contractId,
  status: status,
  hiredAt: DateTime.now().subtract(const Duration(days: 1)),
  jobTitle: 'Hire for $jobId',
);

void main() {
  group('My Jobs consolidation (Hires → My Jobs)', () {
    late _FakeJobService jobService;
    late _FakeHireService hireService;
    late JobProvider jobs;
    late HireProvider hires;

    setUp(() {
      jobService = _FakeJobService(<Job>[
        _job(id: 'job-open', title: 'Open Website Build', status: 'open'),
        _job(id: 'job-awarded', title: 'Awarded Mobile App', status: 'awarded'),
        _job(
          id: 'job-cancelled',
          title: 'Cancelled Logo Work',
          status: 'cancelled',
        ),
        _job(
          id: 'job-disputed',
          title: 'Disputed API Integration',
          status: 'awarded',
        ),
        _job(
          id: 'job-done',
          title: 'Completed Data Entry',
          status: 'completed',
        ),
      ]);
      hireService = _FakeHireService(<Hire>[
        _hire(id: 'hire-pending', jobId: 'job-awarded', status: 'pending'),
        _hire(
          id: 'hire-active',
          jobId: 'job-awarded',
          status: 'active',
          contractId: 'contract-1',
        ),
        _hire(
          id: 'hire-disputed',
          jobId: 'job-disputed',
          status: 'disputed',
          contractId: 'contract-2',
        ),
        _hire(
          id: 'hire-completed',
          jobId: 'job-done',
          status: 'completed',
          contractId: 'contract-3',
        ),
      ]);
      jobs = JobProvider(service: jobService);
      hires = HireProvider(service: hireService);
      addTearDown(() {
        jobs.dispose();
        hires.dispose();
      });
    });

    Future<void> pumpJobs(WidgetTester tester) {
      return pumpScreen(
        tester,
        const MyJobsScreen(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider<HireProvider>.value(value: hires),
        ],
      );
    }

    testWidgets('renders consolidated tabs and engagement actions', (
      WidgetTester tester,
    ) async {
      await pumpJobs(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Extended filter structure: Cancelled + Disputed next to the
      // pre-existing tabs. `Completed` also matches the completed job's
      // status pill and `Disputed` the disputed hire badge, so those match
      // more than the tab alone.
      for (final String tab in <String>[
        'All Jobs',
        'Open',
        'In Progress',
        'Cancelled',
      ]) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Disputed'), findsWidgets);

      // Engagements consolidated from Hires onto the awarded job card.
      expect(find.text('Engagements (2)'), findsOneWidget);
      expect(find.text('Cancel Hire'), findsOneWidget);
      expect(find.text('Complete Hire'), findsOneWidget);
      expect(find.text('File Dispute'), findsWidgets);
      expect(find.text('View Contract'), findsWidgets);
      expect(find.text('Escrow'), findsWidgets);
      expect(find.text('View Hire'), findsWidgets);
      expect(find.text('Message'), findsWidgets);
    });

    testWidgets('cancel hire confirms and calls the hire seam', (
      WidgetTester tester,
    ) async {
      await pumpJobs(tester);
      await tester.pumpAndSettle();

      final Finder cancelHire = find.text('Cancel Hire').first;
      await tester.ensureVisible(cancelHire);
      await tester.pumpAndSettle();
      await tester.tap(cancelHire);
      await tester.pumpAndSettle();
      expect(find.text('Cancel hire?'), findsOneWidget);

      await tester.tap(find.text('Cancel Hire').last);
      await tester.pumpAndSettle();

      expect(hireService.cancelledIds, contains('hire-pending'));
      expect(find.text('Hire cancelled.'), findsOneWidget);
    });

    testWidgets('complete hire calls the hire seam', (
      WidgetTester tester,
    ) async {
      await pumpJobs(tester);
      await tester.pumpAndSettle();

      final Finder completeHire = find.text('Complete Hire').first;
      await tester.ensureVisible(completeHire);
      await tester.pumpAndSettle();
      await tester.tap(completeHire);
      await tester.pumpAndSettle();

      expect(hireService.completedIds, contains('hire-completed'));
      expect(find.text('Hire completed.'), findsOneWidget);
    });

    testWidgets('cancelled and disputed tabs filter correctly', (
      WidgetTester tester,
    ) async {
      await pumpJobs(tester);
      await tester.pumpAndSettle();

      final Finder cancelledTab = find.text('Cancelled');
      await tester.ensureVisible(cancelledTab);
      await tester.pumpAndSettle();
      await tester.tap(cancelledTab);
      await tester.pumpAndSettle();
      expect(find.text('Cancelled Logo Work'), findsOneWidget);
      expect(find.text('Open Website Build'), findsNothing);

      // The Disputed tab shares its label with the hire status badge, so
      // tap the first match (the tab row precedes the cards).
      final Finder disputedTab = find.text('Disputed').first;
      await tester.ensureVisible(disputedTab);
      await tester.pumpAndSettle();
      await tester.tap(disputedTab);
      await tester.pumpAndSettle();
      expect(find.text('Disputed API Integration'), findsOneWidget);
      expect(find.text('Open Website Build'), findsNothing);
      expect(find.text('Cancelled Logo Work'), findsNothing);
    });

    test('client navigation drops Hires; hire detail route is preserved', () {
      final List<String> hireLabels = dashboardNavItems
          .where((item) => item.visibleFor(hire: true, offer: false))
          .map((item) => item.label)
          .toList();
      expect(hireLabels, contains('My Jobs'));
      expect(hireLabels, isNot(contains('Hires')));

      // Engagement deep-links still resolve: the hire-detail destination and
      // the dispute-filing builder remain wired.
      expect(RoutePaths.dashboardHireDetail('h-1'), '/dashboard/hires/h-1');
      expect(
        RoutePaths.disputesFile('contract-1'),
        '/support/disputes/file/contract-1',
      );
    });
  });
}
