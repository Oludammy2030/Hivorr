import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/hires_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/jobs_remote_data_source.dart';
import 'package:hivorr/data/models/hire_dto.dart';
import 'package:hivorr/data/models/hire_envelopes_dto.dart';
import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/models/job_envelopes_dto.dart';
import 'package:hivorr/data/models/job_quotation_dto.dart';
import 'package:hivorr/data/repositories/hire_repository_impl.dart';
import 'package:hivorr/data/repositories/job_repository_impl.dart';

/// Fake jobs transport that records calls and returns canned DTOs.
class FakeJobsRemote implements JobsRemoteDataSource {
  int createCalls = 0;

  static Map<String, dynamic> jobRow() => <String, dynamic>{
    'id': 'job-1',
    'client_entity_id': 'client-1',
    'title': 'Fix my kitchen plumbing issue',
    'description': 'Kitchen sink drainage is blocked and needs attention.',
    'currency_code': 'NGN',
    'status': 'draft',
    'applications_count': 0,
    'created_at': '2026-09-01T09:00:00Z',
    'updated_at': '2026-09-01T09:00:00Z',
  };

  @override
  Future<JobDto> createJob({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  }) async {
    createCalls++;
    return JobDto.fromJson(jobRow());
  }

  @override
  Future<JobDto> updateJob({
    required String jobId,
    String? title,
    String? description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String? currencyCode,
    String? location,
  }) async => JobDto.fromJson(jobRow());

  @override
  Future<JobDto> publishJob(String jobId) async => JobDto.fromJson(jobRow());

  @override
  Future<JobDto> pauseJob(String jobId) async => JobDto.fromJson(jobRow());

  @override
  Future<JobDto> resumeJob(String jobId) async => JobDto.fromJson(jobRow());

  @override
  Future<JobDto> cancelJob(String jobId, {String? reason}) async =>
      JobDto.fromJson(jobRow());

  @override
  Future<JobDto> completeJob(String jobId) async => JobDto.fromJson(jobRow());

  @override
  Future<JobDetailEnvelopeDto> getJob(String jobId) async =>
      JobDetailEnvelopeDto.fromJson(<String, dynamic>{
        'job': jobRow(),
        'applications': <dynamic>[],
        'events': <dynamic>[],
      });

  @override
  Future<JobListEnvelopeDto> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async => const JobListEnvelopeDto(jobs: [], hasMore: false);

  @override
  Future<JobListEnvelopeDto> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const JobListEnvelopeDto(jobs: [], hasMore: false);

  @override
  Future<JobApplicationDto> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  }) async => throw UnimplementedError();

  @override
  Future<JobApplicationDto> withdrawApplication(String applicationId) async =>
      throw UnimplementedError();

  @override
  Future<JobApplicationDto> shortlistApplication(String applicationId) async =>
      throw UnimplementedError();

  @override
  Future<JobApplicationDto> rejectApplication(String applicationId) async =>
      throw UnimplementedError();

  @override
  Future<ApplicationListEnvelopeDto> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) async => throw UnimplementedError();

  @override
  Future<ApplicationListEnvelopeDto> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) async => throw UnimplementedError();
}

/// Fake hires transport — every method throws unless a test needs it.
class FakeHiresRemote implements HiresRemoteDataSource {
  @override
  Future<JobQuotationDto> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  }) async => throw UnimplementedError();

  @override
  Future<JobQuotationDto> withdrawQuotation(String quotationId) async =>
      throw UnimplementedError();

  @override
  Future<JobQuotationDto> acceptQuotation(String quotationId) async =>
      throw UnimplementedError();

  @override
  Future<HireAcceptEnvelopeDto> acceptHire(
    String applicationId, {
    String? quotationId,
  }) async => throw UnimplementedError();

  @override
  Future<HireDetailEnvelopeDto> getHire(String hireId) async =>
      throw UnimplementedError();

  @override
  Future<HireListEnvelopeDto> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const HireListEnvelopeDto(hires: [], hasMore: false);

  @override
  Future<HireDto> cancelHire(String hireId, {String? reason}) async =>
      throw UnimplementedError();

  @override
  Future<HireDto> completeHire(String hireId) async =>
      throw UnimplementedError();
}

void main() {
  group('JobRepositoryImpl fail-fast validation', () {
    test('short title never reaches the RPC (PLT003)', () async {
      final FakeJobsRemote remote = FakeJobsRemote();
      final JobRepositoryImpl repo = JobRepositoryImpl(remote: remote);
      expect(
        () => repo.createJob(
          title: 'Short',
          description:
              'A description that is definitely longer than fifty characters.',
        ),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              )
              .having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.createCalls, 0);
    });

    test('short description never reaches the RPC (PLT003)', () async {
      final FakeJobsRemote remote = FakeJobsRemote();
      final JobRepositoryImpl repo = JobRepositoryImpl(remote: remote);
      expect(
        () => repo.createJob(
          title: 'A perfectly valid job title here',
          description: 'Too short.',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('inverted budget never reaches the RPC (PLT003)', () async {
      final FakeJobsRemote remote = FakeJobsRemote();
      final JobRepositoryImpl repo = JobRepositoryImpl(remote: remote);
      expect(
        () => repo.createJob(
          title: 'A perfectly valid job title here',
          description:
              'A description that is definitely longer than fifty characters.',
          budgetMin: 5000,
          budgetMax: 1000,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('bad role and status filters never reach the RPC', () async {
      final JobRepositoryImpl repo = JobRepositoryImpl(
        remote: FakeJobsRemote(),
      );
      expect(
        () => repo.listMyJobs(role: 'admin'),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.listMyJobs(status: 'bogus'),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.listMyApplications(status: 'bogus'),
        throwsA(isA<ApiException>()),
      );
    });

    test('short cover note never reaches the RPC (PLT003)', () async {
      final JobRepositoryImpl repo = JobRepositoryImpl(
        remote: FakeJobsRemote(),
      );
      expect(
        () => repo.submitApplication(jobId: 'job-1', coverNote: 'Too short'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('HireRepositoryImpl fail-fast validation', () {
    test('zero quotation amount never reaches the RPC', () async {
      final HireRepositoryImpl repo = HireRepositoryImpl(
        remote: FakeHiresRemote(),
      );
      expect(
        () => repo.proposeQuotation(applicationId: 'app-1', amount: 0),
        throwsA(isA<ApiException>()),
      );
    });

    test('bad hire role and status filters never reach the RPC', () async {
      final HireRepositoryImpl repo = HireRepositoryImpl(
        remote: FakeHiresRemote(),
      );
      expect(
        () => repo.listMyHires(role: 'admin'),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.listMyHires(status: 'bogus'),
        throwsA(isA<ApiException>()),
      );
    });

    test('empty ids never reach the RPC', () async {
      final HireRepositoryImpl repo = HireRepositoryImpl(
        remote: FakeHiresRemote(),
      );
      expect(() => repo.getHire('  '), throwsA(isA<ApiException>()));
      expect(() => repo.cancelHire(''), throwsA(isA<ApiException>()));
    });
  });
}
