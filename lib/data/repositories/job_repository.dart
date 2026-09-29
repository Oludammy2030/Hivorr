import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';

/// Repository contract for jobs and applications (EP-04-01).
///
/// Pure domain entities in and out — no DTO or Supabase leakage. Status
/// transitions stay server-authoritative; this contract exposes intent-level
/// operations only.
abstract class JobRepository {
  /// Creates a draft job.
  Future<Job> createJob({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  });

  /// Updates a draft/open/paused job. Only non-null fields are sent.
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
  });

  /// Publishes a draft job.
  Future<Job> publishJob(String jobId);

  /// Pauses an open job.
  Future<Job> pauseJob(String jobId);

  /// Resumes a paused job.
  Future<Job> resumeJob(String jobId);

  /// Cancels a draft/open/paused job.
  Future<Job> cancelJob(String jobId, {String? reason});

  /// Completes an awarded job.
  Future<Job> completeJob(String jobId);

  /// Fetches a job with owner-visible applications and events.
  Future<JobDetail> getJob(String jobId);

  /// Open-job discovery with optional profession/search filter.
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  });

  /// Own jobs: `posted` (client) or `applied` (professional).
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Applies to an open job.
  Future<JobApplication> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  });

  /// Withdraws own submitted/shortlisted application.
  Future<JobApplication> withdrawApplication(String applicationId);

  /// Shortlists a submitted application (owner).
  Future<JobApplication> shortlistApplication(String applicationId);

  /// Rejects a submitted/shortlisted application (owner).
  Future<JobApplication> rejectApplication(String applicationId);

  /// Owner-scoped application list for one job.
  Future<ApplicationPage> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  });

  /// Professional-scoped own applications.
  Future<ApplicationPage> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  });
}

/// A `job_get` result: the job, owner-visible applications, the caller's own
/// application (when an applicant), and the lifecycle events.
class JobDetail {
  const JobDetail({
    required this.job,
    required this.applications,
    this.myApplication,
    this.events = const <Map<String, dynamic>>[],
  });

  /// The job.
  final Job job;

  /// Applications on the job (owner only, else empty).
  final List<JobApplication> applications;

  /// The caller's application when the caller applied.
  final JobApplication? myApplication;

  /// Lifecycle event rows (passthrough maps).
  final List<Map<String, dynamic>> events;
}

/// A keyset page of jobs.
class JobPage {
  const JobPage({required this.jobs, required this.hasMore, this.nextCursor});

  /// The page items.
  final List<Job> jobs;

  /// Whether further pages exist.
  final bool hasMore;

  /// Cursor for the next page, when [hasMore].
  final String? nextCursor;
}

/// A keyset page of applications.
class ApplicationPage {
  const ApplicationPage({
    required this.applications,
    required this.hasMore,
    this.nextCursor,
  });

  /// The page items.
  final List<JobApplication> applications;

  /// Whether further pages exist.
  final bool hasMore;

  /// Cursor for the next page, when [hasMore].
  final String? nextCursor;
}
