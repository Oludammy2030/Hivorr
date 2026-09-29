/// A client-posted hiring need (EP-04-01).
///
/// Mirrors `jobs`
/// (`supabase/migrations/20260928090001_jobs_applications_schema.sql:44-95`).
/// `status` matches the frozen CHECK vocabulary compiled in
/// `lib/systems/jobs/models/job_status.dart`; transitions are
/// server-authoritative — the client never writes status columns and only
/// reads them via `job_get`/`job_list`/`job_list_mine` (AGENT.md Rule 4).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class Job {
  const Job({
    required this.id,
    required this.clientEntityId,
    this.professionId,
    this.industryId,
    required this.title,
    required this.description,
    this.budgetMin,
    this.budgetMax,
    required this.currencyCode,
    this.location,
    required this.status,
    this.applicationsCount = 0,
    this.awardedApplicationId,
    this.postedAt,
    this.awardedAt,
    this.completedAt,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The job row id.
  final String id;

  /// The hiring client that posted the job.
  final String clientEntityId;

  /// Optional taxonomy binding (profession).
  final String? professionId;

  /// Optional taxonomy binding (industry).
  final String? industryId;

  /// Job title, 10–120 chars (CHECK).
  final String title;

  /// Job description, 50–5000 chars (CHECK).
  final String description;

  /// Optional budget floor (non-negative).
  final double? budgetMin;

  /// Optional budget ceiling (>= floor when both set).
  final double? budgetMax;

  /// ISO 4217 currency (active row in financial_supported_currencies).
  final String currencyCode;

  /// Optional free-text location.
  final String? location;

  /// `draft | open | paused | awarded | completed | cancelled`.
  final String status;

  /// Trigger-maintained application count.
  final int applicationsCount;

  /// Winning application id, set by `hire_accept` (EP-04-02).
  final String? awardedApplicationId;

  /// When the job was published.
  final DateTime? postedAt;

  /// When the job was awarded.
  final DateTime? awardedAt;

  /// When the job was completed.
  final DateTime? completedAt;

  /// When the job was cancelled.
  final DateTime? cancelledAt;

  /// When the job was created.
  final DateTime createdAt;

  /// When the job was last updated.
  final DateTime updatedAt;

  /// Whether the job is visible in discovery (`open`).
  bool get isOpen => status == 'open';

  /// Whether the owner may still edit or transition the job.
  bool get isEditable =>
      status == 'draft' || status == 'open' || status == 'paused';

  /// Whether the job has been awarded to a professional.
  bool get isAwarded => status == 'awarded';

  /// Whether the job reached a terminal state.
  bool get isTerminal => status == 'completed' || status == 'cancelled';
}
