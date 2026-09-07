import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';

/// The full dispute read model (case + ordered evidence + optional resolution).
///
/// Mirrors the `dispute_get` envelope `data` object
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:786-827`),
/// which returns `{case, evidence: [...], resolution}` — one RPC per selection
/// (EP-02-17 §13). Rows are server-scoped to the calling party (RLS).
class DisputeCaseDetail {
  const DisputeCaseDetail({
    required this.disputeCase,
    required this.evidence,
    this.resolution,
  });

  /// The dispute case header (`dispute_get` envelope `case`).
  final DisputeCase disputeCase;

  /// Evidence ordered by the server (newest-first contract).
  final List<DisputeEvidence> evidence;

  /// The resolution outcome, when the case has been resolved.
  final DisputeResolution? resolution;

  /// Whether the case has a binding resolution.
  bool get hasResolution => resolution != null;
}