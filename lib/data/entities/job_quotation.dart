/// A per-application price/duration proposal (EP-04-02).
///
/// Mirrors `job_quotations`
/// (`supabase/migrations/20260928090002_quotations_hires_schema.sql:41-82`).
/// Quotations form a revision chain per application: exactly one `proposed`
/// row at a time (partial unique index); older rows are `superseded`.
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class JobQuotation {
  const JobQuotation({
    required this.id,
    required this.applicationId,
    required this.proposedBy,
    required this.proposedAmount,
    required this.currencyCode,
    this.durationDays,
    this.message,
    required this.revisionNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.decidedAt,
  });

  /// The quotation row id.
  final String id;

  /// The application this quotes for.
  final String applicationId;

  /// The proposing professional.
  final String proposedBy;

  /// Proposed price (positive).
  final double proposedAmount;

  /// ISO 4217 currency.
  final String currencyCode;

  /// Optional duration in days (>= 1 when set).
  final int? durationDays;

  /// Optional note (<= 2000 chars).
  final String? message;

  /// Monotonic revision per application (starts at 1).
  final int revisionNumber;

  /// `proposed | accepted | superseded | withdrawn`.
  final String status;

  /// When the quotation was proposed.
  final DateTime createdAt;

  /// When the row was last updated.
  final DateTime updatedAt;

  /// When the quotation was decided, if applicable.
  final DateTime? decidedAt;

  /// Whether the quotation is the live one for its application.
  bool get isLive => status == 'proposed';

  /// Whether the quotation may be used for hiring.
  bool get isHirable => status == 'proposed' || status == 'accepted';
}
