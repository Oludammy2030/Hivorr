// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/jobs_remote_data_source.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/mappers/job_mapper.dart';
import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/repositories/job_repository.dart';

/// Default implementation of [JobRepository].
///
/// Implements the server-authoritative jobs flow (EP-04-01): reads via
/// `job_get`/`job_list`/`job_list_mine`/`application_list_*` mapped through
/// [JobMapper]; writes via the client-callable RPCs. Known CHECK constraints
/// are pre-validated client-side (title 10–120, description 50–5000, cover
/// note 20–2000, positive amounts, frozen vocabularies) so a preventable
/// `PLT003` never round-trips. This implementation never writes jobs tables
/// directly (AGENT.md Rule 4).
class JobRepositoryImpl implements JobRepository {
  JobRepositoryImpl({required JobsRemoteDataSource remote}) : _remote = remote;

  final JobsRemoteDataSource _remote;

  // Validation mirrors of the frozen CHECK constraints
  // (`20260928090001_jobs_applications_schema.sql:61-92,122-137`) and the
  // systems-layer vocabulary (`lib/systems/jobs/models/job_status.dart`).
  // The server remains the single authority; the repository mirrors the codes
  // for fail-fast UX only.
  static const Set<String> _jobStatuses = <String>{
    'draft',
    'open',
    'paused',
    'awarded',
    'completed',
    'cancelled',
  };
  static const Set<String> _applicationStatuses = <String>{
    'submitted',
    'withdrawn',
    'shortlisted',
    'accepted',
    'rejected',
  };
  static const Set<String> _mineRoles = <String>{'posted', 'applied'};

  @override
  Future<Job> createJob({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  }) async {
    _requireLength(title, min: 10, max: 120, field: 'title');
    _requireLength(description, min: 50, max: 5000, field: 'description');
    _requireBudgetRange(budgetMin, budgetMax);
    _requireCurrency(currencyCode);
    if (professionId != null) _requireNonEmpty(professionId, 'professionId');
    if (industryId != null) _requireNonEmpty(industryId, 'industryId');
    final JobDto dto = await _remote.createJob(
      title: title.trim(),
      description: description.trim(),
      professionId: professionId,
      industryId: industryId,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currencyCode: currencyCode,
      location: location?.trim(),
    );
    return JobMapper.jobToEntity(dto);
  }

  @override
  Future<Job> updateJob({
    required String jobId,
    String? title,
    String? description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String? currencyCode,
    String? location,
  }) async {
    _requireNonEmpty(jobId, 'jobId');
    if (title != null) _requireLength(title, min: 10, max: 120, field: 'title');
    if (description != null) {
      _requireLength(description, min: 50, max: 5000, field: 'description');
    }
    if (budgetMin != null && budgetMin < 0) {
      _fail('Minimum budget cannot be negative.');
    }
    if (budgetMax != null && budgetMax < 0) {
      _fail('Maximum budget cannot be negative.');
    }
    if (currencyCode != null) _requireCurrency(currencyCode);
    final JobDto dto = await _remote.updateJob(
      jobId: jobId,
      title: title?.trim(),
      description: description?.trim(),
      professionId: professionId,
      industryId: industryId,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currencyCode: currencyCode,
      location: location?.trim(),
    );
    return JobMapper.jobToEntity(dto);
  }

  @override
  Future<Job> publishJob(String jobId) async {
    _requireNonEmpty(jobId, 'jobId');
    return JobMapper.jobToEntity(await _remote.publishJob(jobId));
  }

  @override
  Future<Job> pauseJob(String jobId) async {
    _requireNonEmpty(jobId, 'jobId');
    return JobMapper.jobToEntity(await _remote.pauseJob(jobId));
  }

  @override
  Future<Job> resumeJob(String jobId) async {
    _requireNonEmpty(jobId, 'jobId');
    return JobMapper.jobToEntity(await _remote.resumeJob(jobId));
  }

  @override
  Future<Job> cancelJob(String jobId, {String? reason}) async {
    _requireNonEmpty(jobId, 'jobId');
    return JobMapper.jobToEntity(
      await _remote.cancelJob(jobId, reason: reason),
    );
  }

  @override
  Future<Job> completeJob(String jobId) async {
    _requireNonEmpty(jobId, 'jobId');
    return JobMapper.jobToEntity(await _remote.completeJob(jobId));
  }

  @override
  Future<JobDetail> getJob(String jobId) async {
    _requireNonEmpty(jobId, 'jobId');
    final dto = await _remote.getJob(jobId);
    return JobDetail(
      job: JobMapper.jobToEntity(dto.job),
      applications: dto.applications
          .map(JobMapper.applicationToEntity)
          .toList(growable: false),
      myApplication: dto.myApplication == null
          ? null
          : JobMapper.applicationToEntity(dto.myApplication!),
      events: dto.events,
    );
  }

  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async {
    _requireLimit(limit);
    final dto = await _remote.listJobs(
      professionId: professionId,
      search: search?.trim().isEmpty ?? true ? null : search?.trim(),
      limit: limit,
      cursor: cursor,
    );
    return JobPage(
      jobs: JobMapper.listEnvelopeToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    _requireInVocabulary(role, _mineRoles, 'role');
    if (status != null) _requireInVocabulary(status, _jobStatuses, 'status');
    _requireLimit(limit);
    final dto = await _remote.listMyJobs(
      role: role,
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return JobPage(
      jobs: JobMapper.listEnvelopeToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  @override
  Future<JobApplication> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  }) async {
    _requireNonEmpty(jobId, 'jobId');
    _requireLength(coverNote, min: 20, max: 2000, field: 'coverNote');
    if (quotedAmount != null && quotedAmount <= 0) {
      _fail('Quoted amount must be greater than zero.');
    }
    _requireCurrency(currencyCode);
    if (durationDays != null && durationDays < 1) {
      _fail('Duration must be at least 1 day.');
    }
    final JobApplicationDto dto = await _remote.submitApplication(
      jobId: jobId,
      coverNote: coverNote.trim(),
      quotedAmount: quotedAmount,
      currencyCode: currencyCode,
      durationDays: durationDays,
    );
    return JobMapper.applicationToEntity(dto);
  }

  @override
  Future<JobApplication> withdrawApplication(String applicationId) async {
    _requireNonEmpty(applicationId, 'applicationId');
    return JobMapper.applicationToEntity(
      await _remote.withdrawApplication(applicationId),
    );
  }

  @override
  Future<JobApplication> shortlistApplication(String applicationId) async {
    _requireNonEmpty(applicationId, 'applicationId');
    return JobMapper.applicationToEntity(
      await _remote.shortlistApplication(applicationId),
    );
  }

  @override
  Future<JobApplication> rejectApplication(String applicationId) async {
    _requireNonEmpty(applicationId, 'applicationId');
    return JobMapper.applicationToEntity(
      await _remote.rejectApplication(applicationId),
    );
  }

  @override
  Future<ApplicationPage> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    _requireNonEmpty(jobId, 'jobId');
    if (status != null) {
      _requireInVocabulary(status, _applicationStatuses, 'status');
    }
    _requireLimit(limit);
    final dto = await _remote.listApplicationsForJob(
      jobId,
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return ApplicationPage(
      applications: JobMapper.applicationListToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  @override
  Future<ApplicationPage> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    if (status != null) {
      _requireInVocabulary(status, _applicationStatuses, 'status');
    }
    _requireLimit(limit);
    final dto = await _remote.listMyApplications(
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return ApplicationPage(
      applications: JobMapper.applicationListToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  void _requireBudgetRange(double? min, double? max) {
    if (min != null && min < 0) _fail('Minimum budget cannot be negative.');
    if (max != null && max < 0) _fail('Maximum budget cannot be negative.');
    if (min != null && max != null && max < min) {
      _fail('Maximum budget must be at least the minimum budget.');
    }
  }

  void _requireCurrency(String currency) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency.trim().toUpperCase())) {
      _fail('Invalid currency code.');
    }
  }

  void _requireLimit(int limit) {
    if (limit < 1 || limit > 100) {
      _fail('Limit must be between 1 and 100.');
    }
  }

  static void _fail(String message) {
    throw ApiException(
      kind: ApiExceptionKind.validation,
      message: message,
      code: 'PLT003',
    );
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      _fail('$field is required.');
    }
  }

  static void _requireInVocabulary(
    String value,
    Set<String> vocabulary,
    String field,
  ) {
    if (!vocabulary.contains(value)) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid $field value: $value.',
        code: 'PLT003',
      );
    }
  }

  static void _requireLength(
    String value, {
    required int min,
    required int max,
    required String field,
  }) {
    final int length = value.trim().length;
    if (length < min || length > max) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: '$field must be between $min and $max characters.',
        code: 'PLT003',
      );
    }
  }
}
