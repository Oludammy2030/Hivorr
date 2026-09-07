/// A formal dispute raised against an escrow (EP-02-17).
///
/// Mirrors `dispute_cases`
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:54-101`).
/// `dispute_type`/`status`/`desired_outcome`/`priority` match the frozen CHECK
/// vocabularies compiled in
/// `lib/systems/support/models/dispute_status.dart`; status transitions are
/// server-authoritative — the client never writes status columns and only
/// reads them via `dispute_get`/`dispute_list` (AGENT.md Rule 4).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports.
class DisputeCase {
  const DisputeCase({
    required this.id,
    required this.escrowId,
    required this.filerEntityId,
    required this.counterpartyEntityId,
    required this.disputeType,
    required this.status,
    required this.reason,
    this.desiredOutcome,
    this.priority = 'medium',
    required this.filedAt,
    this.resolvedAt,
    this.closedAt,
    this.withdrawnAt,
    this.metadata = const <String, dynamic>{},
  });

  /// The dispute case row id.
  final String id;

  /// The escrow this dispute freezes (`financial_escrow.id`).
  final String escrowId;

  /// The entity that filed the dispute.
  final String filerEntityId;

  /// The other party to the dispute.
  final String counterpartyEntityId;

  /// `service_quality | non_delivery | milestone_disagreement | fraud | other`
  /// (CHECK `62-65`).
  final String disputeType;

  /// `open | under_review | resolved | closed | withdrawn` (CHECK `66-68`).
  final String status;

  /// Free-text dispute reason, 10–2000 chars after trim (CHECK `69-70`).
  final String reason;

  /// `release_to_payee | refund_to_payer | split | other`, nullable
  /// (CHECK `71-73`).
  final String? desiredOutcome;

  /// `low | medium | high | critical` (CHECK `74-75`); defaults to `medium`.
  final String priority;

  /// When the dispute was filed.
  final DateTime filedAt;

  /// When the dispute was resolved, if applicable.
  final DateTime? resolvedAt;

  /// When the dispute was closed, if applicable.
  final DateTime? closedAt;

  /// When the dispute was withdrawn, if applicable.
  final DateTime? withdrawnAt;

  /// Server-side case metadata (passthrough).
  final Map<String, dynamic> metadata;

  /// Whether the case is still actionable (`open`).
  bool get isOpen => status == 'open';

  /// Whether evidence may still be submitted (`open`/`under_review`).
  bool get acceptsEvidence =>
      status == 'open' || status == 'under_review';

  /// Whether the case was withdrawn (hold released server-side).
  bool get isWithdrawn => status == 'withdrawn';
}