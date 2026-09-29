/// The hiring bridge between a won application and its engagement contract
/// (EP-04-02).
///
/// Mirrors `hires`
/// (`supabase/migrations/20260928090002_quotations_hires_schema.sql:84-125`).
/// Money, milestones, messaging and reviews live on the linked
/// `service_contracts` row; [effectiveStatus] (carried alongside, never
/// persisted client-side) derives from the contract:
/// offered->pending, active->active, completed/closed->completed,
/// cancelled->cancelled, disputed->disputed.
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class Hire {
  const Hire({
    required this.id,
    required this.jobId,
    required this.applicationId,
    this.quotationId,
    required this.clientEntityId,
    required this.professionalEntityId,
    this.contractId,
    required this.status,
    required this.hiredAt,
    this.completedAt,
    this.cancelledAt,
    this.effectiveStatus,
    this.jobTitle,
    this.jobStatus,
  });

  /// The hire row id.
  final String id;

  /// The awarded job.
  final String jobId;

  /// The winning application.
  final String applicationId;

  /// The chosen quotation, when the hire used one.
  final String? quotationId;

  /// The hiring client.
  final String clientEntityId;

  /// The hired professional.
  final String professionalEntityId;

  /// The linked `service_contracts` row (set atomically by `hire_accept`).
  final String? contractId;

  /// Stored status (`pending | active | completed | cancelled | disputed`).
  final String status;

  /// When the hire was created.
  final DateTime hiredAt;

  /// When the hire completed, if applicable.
  final DateTime? completedAt;

  /// When the hire was cancelled, if applicable.
  final DateTime? cancelledAt;

  /// Contract-derived live status (`hire_get`/`hire_list_mine` only).
  final String? effectiveStatus;

  /// Denormalized job title (`hire_list_mine` only).
  final String? jobTitle;

  /// Denormalized job status (`hire_list_mine` only).
  final String? jobStatus;

  /// The live status: contract-derived when present, else stored.
  String get liveStatus => effectiveStatus ?? status;

  /// Whether work may still start on this hire.
  bool get isPending => liveStatus == 'pending';

  /// Whether the hire is actively being worked.
  bool get isActive => liveStatus == 'active';

  /// Copies this hire with the contract-derived [effectiveStatus] applied.
  Hire copyWithEffective(String effectiveStatus) => Hire(
    id: id,
    jobId: jobId,
    applicationId: applicationId,
    quotationId: quotationId,
    clientEntityId: clientEntityId,
    professionalEntityId: professionalEntityId,
    contractId: contractId,
    status: status,
    hiredAt: hiredAt,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    effectiveStatus: effectiveStatus,
    jobTitle: jobTitle,
    jobStatus: jobStatus,
  );
}
