import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';

/// Contract for dispute transport (EP-02-17 §5.3).
///
/// Wraps exactly the **five client-callable** RPCs granted to `authenticated`
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:867-871`):
/// `dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`,
/// `dispute_list`. The server-granted `dispute_resolve` is deliberately
/// **absent** — no resolve method exists on this contract (EP-02-17 §9.2).
abstract class DisputeRemoteDataSource {
  /// Lists dispute cases, optionally filtered by [status]
  /// (`dispute_list`, STABLE).
  Future<DisputeListEnvelopeDto> listDisputes({String? status});

  /// Fetches a single case + ordered evidence + optional resolution
  /// (`dispute_get`, STABLE).
  Future<DisputeCaseDetailEnvelopeDto> getCase(String caseId);

  /// Files a dispute and places the automatic escrow hold (`dispute_file`).
  Future<DisputeCaseDto> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  });

  /// Submits immutable evidence against a case (`dispute_submit_evidence`).
  ///
  /// [fileUrl] must already be a `credential-documents` storage path from a
  /// completed [StorageService.upload] — upload happens before this RPC.
  Future<DisputeEvidenceDto> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  });

  /// Withdraws a dispute and releases the escrow hold (`dispute_withdraw`).
  Future<DisputeCaseDto> withdrawDispute(String caseId);
}