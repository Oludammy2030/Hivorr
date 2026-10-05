// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/jobs/models/job_status.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [JobRepository] consumed by [JobProvider] and the jobs
/// screens (EP-04-01).
///
/// Exposes the job/application status vocabularies (compile-time const,
/// mirroring the frozen CHECK constraints) plus the fail-fast validators
/// [validateTitle]/[validateDescription]/[validateCoverNote], and delegates
/// data operations to the repository. Adds PII-safe structured [HivorrLogger]
/// output (ids, status deltas — never titles, descriptions, or cover notes)
/// and `jobs.*` [PerformanceTracer] spans.
class JobService {
  JobService({
    required JobRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _repository = repository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final JobRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints, EP-04-01) ──────────

  /// The 6-state job status vocabulary.
  static const List<String> jobStatusList = jobStatusCodes;

  /// The 5-state application status vocabulary.
  static const List<String> applicationStatusList = applicationStatusCodes;

  /// Resolves the display entry for a hiring [code].
  HiringStatus? statusFor(String code) => HiringStatus.forCode(code);

  // ─── Fail-fast validators (mirror CHECK lengths) ──────────────────────

  /// `true` when [title] is 10–120 chars after trim.
  static bool validateTitle(String title) {
    final int length = title.trim().length;
    return length >= 10 && length <= 120;
  }

  /// `true` when [description] is 50–5000 chars after trim.
  static bool validateDescription(String description) {
    final int length = description.trim().length;
    return length >= 50 && length <= 5000;
  }

  /// `true` when [coverNote] is 20–2000 chars after trim.
  static bool validateCoverNote(String coverNote) {
    final int length = coverNote.trim().length;
    return length >= 20 && length <= 2000;
  }

  // ─── Data operations (delegate to repository, traced + logged) ────────

  Future<Job> createJob({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  }) => _tracedAndLogged('jobs.create', () async {
    final Job job = await _repository.createJob(
      title: title,
      description: description,
      professionId: professionId,
      industryId: industryId,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currencyCode: currencyCode,
      location: location,
    );
    _logger?.info('Job created', <String, Object?>{
      'jobId': _redactor.redact(job.id),
      'status': job.status,
    });
    return job;
  });

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
  }) => _tracedAndLogged('jobs.update', () async {
    final Job job = await _repository.updateJob(
      jobId: jobId,
      title: title,
      description: description,
      professionId: professionId,
      industryId: industryId,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      currencyCode: currencyCode,
      location: location,
    );
    _logger?.info('Job updated', <String, Object?>{
      'jobId': _redactor.redact(jobId),
      'status': job.status,
    });
    return job;
  });

  Future<Job> publishJob(String jobId) =>
      _tracedAndLogged('jobs.publish', () async {
        final Job job = await _repository.publishJob(jobId);
        _logger?.info('Job published', <String, Object?>{
          'jobId': _redactor.redact(jobId),
        });
        return job;
      });

  Future<Job> pauseJob(String jobId) =>
      _tracedAndLogged('jobs.pause', () async {
        return _repository.pauseJob(jobId);
      });

  Future<Job> resumeJob(String jobId) =>
      _tracedAndLogged('jobs.resume', () async {
        return _repository.resumeJob(jobId);
      });

  Future<Job> cancelJob(String jobId, {String? reason}) =>
      _tracedAndLogged('jobs.cancel', () async {
        return _repository.cancelJob(jobId, reason: reason);
      });

  Future<Job> completeJob(String jobId) =>
      _tracedAndLogged('jobs.complete', () async {
        return _repository.completeJob(jobId);
      });

  Future<JobDetail> getJob(String jobId) =>
      _tracedAndLogged('jobs.get', () async {
        final JobDetail detail = await _repository.getJob(jobId);
        _logger?.info('Job detail fetched', <String, Object?>{
          'jobId': _redactor.redact(jobId),
          'status': detail.job.status,
          'applicationCount': detail.applications.length,
        });
        return detail;
      });

  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('jobs.list', () async {
    return _repository.listJobs(
      professionId: professionId,
      search: search,
      limit: limit,
      cursor: cursor,
    );
  });

  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('jobs.list_mine', () async {
    return _repository.listMyJobs(
      role: role,
      status: status,
      limit: limit,
      cursor: cursor,
    );
  });

  Future<JobApplication> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  }) => _tracedAndLogged('jobs.apply', () async {
    final JobApplication application = await _repository.submitApplication(
      jobId: jobId,
      coverNote: coverNote,
      quotedAmount: quotedAmount,
      currencyCode: currencyCode,
      durationDays: durationDays,
    );
    _logger?.info('Application submitted', <String, Object?>{
      'applicationId': _redactor.redact(application.id),
      'jobId': _redactor.redact(jobId),
    });
    return application;
  });

  Future<JobApplication> withdrawApplication(String applicationId) =>
      _tracedAndLogged('jobs.withdraw', () async {
        return _repository.withdrawApplication(applicationId);
      });

  Future<JobApplication> shortlistApplication(String applicationId) =>
      _tracedAndLogged('jobs.shortlist', () async {
        return _repository.shortlistApplication(applicationId);
      });

  Future<JobApplication> rejectApplication(String applicationId) =>
      _tracedAndLogged('jobs.reject', () async {
        return _repository.rejectApplication(applicationId);
      });

  Future<ApplicationPage> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('jobs.applications_for_job', () async {
    return _repository.listApplicationsForJob(
      jobId,
      status: status,
      limit: limit,
      cursor: cursor,
    );
  });

  Future<ApplicationPage> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('jobs.applications_mine', () async {
    return _repository.listMyApplications(
      status: status,
      limit: limit,
      cursor: cursor,
    );
  });

  /// Wraps [action] in a `jobs.*` [PerformanceTracer] span and surfaces
  /// failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'jobs');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}
