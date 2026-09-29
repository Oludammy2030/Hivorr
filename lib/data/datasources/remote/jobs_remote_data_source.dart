import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/models/job_envelopes_dto.dart';

/// Contract for jobs/applications transport (EP-04-01).
///
/// Wraps exactly the **sixteen client-callable** RPCs granted to
/// `authenticated`
/// (`supabase/migrations/20260928090001_jobs_applications_schema.sql:1169-1184`):
/// `job_create/update/publish/pause/resume/cancel/complete/get/list/list_mine`
/// and `application_submit/withdraw/shortlist/reject/list_for_job/list_mine`.
abstract class JobsRemoteDataSource {
  /// Creates a draft job (`job_create`, VOLATILE).
  Future<JobDto> createJob({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  });

  /// Updates a draft/open/paused job (`job_update`, VOLATILE).
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
  });

  /// Publishes a draft job (`job_publish`, VOLATILE).
  Future<JobDto> publishJob(String jobId);

  /// Pauses an open job (`job_pause`, VOLATILE).
  Future<JobDto> pauseJob(String jobId);

  /// Resumes a paused job (`job_resume`, VOLATILE).
  Future<JobDto> resumeJob(String jobId);

  /// Cancels a draft/open/paused job (`job_cancel`, VOLATILE).
  Future<JobDto> cancelJob(String jobId, {String? reason});

  /// Completes an awarded job (`job_complete`, VOLATILE).
  Future<JobDto> completeJob(String jobId);

  /// Fetches a job + applications/events (`job_get`, STABLE).
  Future<JobDetailEnvelopeDto> getJob(String jobId);

  /// Open-job discovery (`job_list`, STABLE).
  Future<JobListEnvelopeDto> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  });

  /// Own jobs: posted (client) or applied (professional)
  /// (`job_list_mine`, STABLE).
  Future<JobListEnvelopeDto> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Applies to an open job (`application_submit`, VOLATILE).
  Future<JobApplicationDto> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  });

  /// Withdraws own submitted/shortlisted application
  /// (`application_withdraw`, VOLATILE).
  Future<JobApplicationDto> withdrawApplication(String applicationId);

  /// Shortlists a submitted application (owner, `application_shortlist`).
  Future<JobApplicationDto> shortlistApplication(String applicationId);

  /// Rejects a submitted/shortlisted application (owner,
  /// `application_reject`).
  Future<JobApplicationDto> rejectApplication(String applicationId);

  /// Owner-scoped application list for one job (`application_list_for_job`).
  Future<ApplicationListEnvelopeDto> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Professional-scoped own applications (`application_list_mine`).
  Future<ApplicationListEnvelopeDto> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  });
}
