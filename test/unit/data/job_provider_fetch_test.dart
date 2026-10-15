import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';

/// Minimal [JobRepository] stub serving one canned detail.
class _StubJobRepository implements JobRepository {
  _StubJobRepository(this.detail);

  final JobDetail detail;
  int getJobCalls = 0;

  @override
  Future<JobDetail> getJob(String jobId) async {
    getJobCalls++;
    return detail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Job _job() => Job(
  id: 'job-1',
  clientEntityId: 'client-1',
  title: 'Fix my sink',
  description: 'A description that is definitely longer than fifty characters.',
  currencyCode: 'NGN',
  status: 'open',
  businessId: 'biz-1',
  clientDisplayName: 'Amara Diallo',
  clientBusinessName: 'Amara Foods',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('JobProvider.fetchJob (identity read-only seam)', () {
    test('returns the detail without touching selection or load state', () async {
      final JobProvider provider = JobProvider(
        service: JobService(
          repository: _StubJobRepository(
            JobDetail(job: _job(), applications: const []),
          ),
        ),
      );
      addTearDown(provider.dispose);

      final JobDetail detail = await provider.fetchJob('job-1');

      expect(detail.job.id, 'job-1');
      expect(detail.job.clientBusinessName, 'Amara Foods');
      expect(detail.job.clientDisplayName, 'Amara Diallo');
      expect(provider.isLoading, isFalse);
      expect(provider.lastError, isNull);
    });
  });
}
