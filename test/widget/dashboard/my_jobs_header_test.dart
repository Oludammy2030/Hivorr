import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/my_jobs_screen.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/harnesses/widget_harness.dart';

class _StubJobService implements JobService {
  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => JobPage(
    jobs: <Job>[
      _job('job-1', 'Senior React Developer', 'open'),
      _job('job-2', 'Office Renovation & Electrical Works Job', 'awarded'),
    ],
    hasMore: false,
    nextCursor: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Job _job(String id, String title, String status) {
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
    status: status,
    applicationsCount: 3,
    postedAt: now.subtract(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
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

void main() {
  group('My Jobs section header (mobile)', () {
    testWidgets('title stays one line with a balanced CTA', (tester) async {
      for (final double width in <double>[320, 360, 390, 414, 599]) {
        final JobProvider jobs = JobProvider(service: _StubJobService());
        final HireProvider hires = HireProvider(service: _StubHireService());
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

        // Single-line title + live metadata + CTA share one row.
        final Finder title = find.text('My Posted Jobs');
        expect(title, findsOneWidget);
        expect(tester.widget<Text>(title).maxLines, 1);
        expect(find.text('2 jobs · 1 open'), findsOneWidget);
        expect(find.text('Post New Job'), findsOneWidget);

        // Button vertically overlaps the text block (balanced, same row).
        final Rect metaBox = tester.getRect(find.text('2 jobs · 1 open'));
        final Rect buttonBox = tester.getRect(find.text('Post New Job'));
        expect(buttonBox.top, lessThan(metaBox.bottom));
        expect(buttonBox.bottom, greaterThan(metaBox.top));
        jobs.dispose();
        hires.dispose();
      }
    });
  });
}
