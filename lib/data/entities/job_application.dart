/// A professional's application to a client-posted job (EP-04-01).
///
/// Mirrors `job_applications`
/// (`supabase/migrations/20260928090001_jobs_applications_schema.sql:108-149`).
/// One row per (job, professional). `status` matches the frozen CHECK
/// vocabulary; transitions are server-authoritative (AGENT.md Rule 4).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.professionalEntityId,
    required this.clientEntityId,
    required this.coverNote,
    this.quotedAmount,
    required this.currencyCode,
    this.durationDays,
    required this.status,
    required this.submittedAt,
    this.decidedAt,
    required this.createdAt,
    required this.updatedAt,
    this.jobTitle,
    this.jobStatus,
  });

  /// The application row id.
  final String id;

  /// The job applied to (`jobs.id`).
  final String jobId;

  /// The applying professional.
  final String professionalEntityId;

  /// Denormalized job owner (acyclic RLS scope).
  final String clientEntityId;

  /// Cover note, 20–2000 chars (CHECK).
  final String coverNote;

  /// Optional proposed price (positive when set).
  final double? quotedAmount;

  /// ISO 4217 currency.
  final String currencyCode;

  /// Optional duration in days (>= 1 when set).
  final int? durationDays;

  /// `submitted | withdrawn | shortlisted | accepted | rejected`.
  final String status;

  /// When the application was submitted.
  final DateTime submittedAt;

  /// When the application reached a decided state, if applicable.
  final DateTime? decidedAt;

  /// When the row was created.
  final DateTime createdAt;

  /// When the row was last updated.
  final DateTime updatedAt;

  /// Denormalized job title (`application_list_mine` only).
  final String? jobTitle;

  /// Denormalized job status (`application_list_mine` only).
  final String? jobStatus;

  /// Whether the applicant may still withdraw.
  bool get isWithdrawable => status == 'submitted' || status == 'shortlisted';

  /// Whether the application is still in the hiring funnel.
  bool get isActive => status == 'submitted' || status == 'shortlisted';

  /// Whether the application won the job.
  bool get isAccepted => status == 'accepted';
}
