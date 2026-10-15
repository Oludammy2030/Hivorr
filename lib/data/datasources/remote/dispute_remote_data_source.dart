import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';
import 'package:hivorr/data/models/service_dispute_detail_envelope_dto.dart';

/// Contract for dispute transport (EP-02-17 §5.3, extended EP-03-17).
///
/// Wraps exactly the **five client-callable** RPCs granted to `authenticated`
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:867-871`):
/// `dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`,
/// `dispute_list` — plus the three contract-scoped EP-03-17 RPCs
/// (`supabase/migrations/20261011090001_service_dispute_contract_link.sql` §7):
/// `service_dispute_file`, `service_dispute_get`,
/// `service_dispute_list_for_contract`. The server-granted `dispute_resolve`
/// is deliberately **absent** — no resolve method exists on this contract
/// (EP-02-17 §9.2).
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

  /// Files a service-engagement dispute and freezes the linked contract
  /// (plus the escrow hold when the contract is funded).
  ///
  /// Thin contract-scoped wrapper over the same server enforcement as
  /// `dispute_file`: the server resolves `escrow_id` from
  /// `service_contracts.escrow_id`, so callers never supply an escrow id and
  /// unfunded contracts remain disputable.
  Future<DisputeCaseDto> fileServiceDispute({
    required String contractId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  });

  /// Fetches a single service-engagement case with ordered evidence, optional
  /// resolution, and the joined service-contract summary
  /// (`service_dispute_get`, STABLE).
  Future<ServiceDisputeDetailEnvelopeDto> getServiceCase(String caseId);

  /// Lists dispute cases for one service contract, optionally filtered by
  /// [status] (`service_dispute_list_for_contract`, STABLE).
  Future<DisputeListEnvelopeDto> listDisputesForContract(
    String contractId, {
    String? status,
  });
}
