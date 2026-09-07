/// A binding admin resolution recorded against a dispute case (EP-02-17).
///
/// Mirrors `dispute_resolutions`
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:135-152`).
/// `resolution_type` matches the frozen CHECK vocabulary
/// (`release_to_payee|refund_to_payer|split|dismissed`, CHECK `141-143`),
/// `reasoning` is 10–5000 chars (`144-145`), amounts are ≥0 (`146-147`).
///
/// Created **only** by the server-granted `dispute_resolve` RPC — the
/// client displays outcomes read-only via `dispute_get` and never writes this
/// table (EP-02-17 §9.2).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class DisputeResolution {
  const DisputeResolution({
    required this.id,
    required this.caseId,
    this.resolvedBy,
    required this.resolutionType,
    required this.reasoning,
    this.payerRefundAmount = 0.0,
    this.payeeReleaseAmount = 0.0,
    this.notes,
    required this.resolvedAt,
    required this.createdAt,
  });

  /// The resolution row id.
  final String id;

  /// The dispute case this resolution binds.
  final String caseId;

  /// The entity that executed the resolution, when known.
  final String? resolvedBy;

  /// `release_to_payee | refund_to_payer | split | dismissed` (CHECK `141-143`).
  final String resolutionType;

  /// Admin reasoning, 10–5000 chars, shown in full to both parties.
  final String reasoning;

  /// Amount refunded to the payer (≥0).
  final double payerRefundAmount;

  /// Amount released to the payee (≥0).
  final double payeeReleaseAmount;

  /// Optional decision notes.
  final String? notes;

  /// When the resolution was recorded.
  final DateTime resolvedAt;

  /// When the resolution row was created.
  final DateTime createdAt;
}