import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';

/// Abstract contract for dispute data operations (EP-02-17 §5.4, EP-03-17).
///
/// Depends only on domain entities and value objects — never on concrete
/// backend types — so business systems and UI consume this interface rather
/// than a Supabase implementation (ARCHITECTURE.md / EP-01-08 §5.6).
///
/// All writes flow through the client-callable RPCs (`dispute_file`,
/// `dispute_submit_evidence`, `dispute_withdraw`, plus the contract-scoped
/// `service_dispute_file`); this repository **never** writes the four dispute
/// tables directly and **never** calls `dispute_resolve` (server-granted only,
/// EP-02-17 §9.2).
abstract class DisputeRepository {
  /// Lists dispute cases for the calling party, optionally filtered by [status]
  /// (client-validated against the frozen CHECK vocabulary before the RPC).
  Future<List<DisputeCase>> listDisputes({String? status});

  /// Fetches a single case + ordered evidence + optional resolution in one RPC.
  Future<DisputeCaseDetail> getCase(String caseId);

  /// Files a dispute and places the automatic escrow hold.
  ///
  /// Pre-validates reason length (10–2000 after trim), dispute type, desired
  /// outcome, and priority against the frozen CHECK vocabularies before the
  /// RPC; re-reads the authoritative case on success.
  Future<DisputeCase> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  });

  /// Submits immutable evidence against a case.
  ///
  /// Pre-validates evidence type (4-value vocab), title length (1–255), and
  /// description (≤2000). [fileUrl] must reference a completed
  /// `credential-documents` upload.
  Future<DisputeEvidence> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  });

  /// Withdraws a dispute and releases the escrow hold.
  ///
  /// Filer/status scoping is enforced server-side inside the SECURITY DEFINER
  /// body; the UI only offers withdrawal when `status == 'open'` and the caller
  /// is the filer.
  Future<DisputeCase> withdrawDispute(String caseId);

  /// Files a service-engagement dispute against a contract (EP-03-17).
  ///
  /// Contract-scoped counterpart of [fileDispute]: the server resolves the
  /// escrow from `service_contracts.escrow_id`, so unfunded contracts remain
  /// disputable. Same client pre-validation as [fileDispute] plus a non-empty
  /// `contractId`; re-reads the authoritative case (with the joined contract
  /// summary) on success.
  Future<DisputeCaseDetail> fileServiceDispute({
    required String contractId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  });

  /// Fetches a single service-engagement case with the joined contract summary
  /// in one RPC (`service_dispute_get`).
  Future<DisputeCaseDetail> getServiceCase(String caseId);

  /// Lists dispute cases for one service contract, optionally filtered by
  /// [status] (client-validated before the RPC).
  Future<List<DisputeCase>> listDisputesForContract(
    String contractId, {
    String? status,
  });
}
