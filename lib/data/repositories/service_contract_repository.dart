import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';

/// Abstract contract for service contract data operations (EP-03-10 §8 D4).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface rather than a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
///
/// All contract writes flow through the client-callable RPCs
/// (`service_contract_offer/accept/cancel/complete_milestone/verify_milestone/
/// close`); this repository **never** writes `service_contracts`,
/// `contract_milestones`, or `contract_events` tables directly and **never**
/// attempts service-role-only transitions (`active→cancelled`).
abstract class ServiceContractRepository {
  /// Creates an `offered` contract with its `pending` milestones, then
  /// re-reads the authoritative row via `service_contract_get`.
  ///
  /// Pre-validates the milestone invariant (`sum == total` within `0.01`),
  /// title (1–255), description (≤2000), amounts (>0), numbering
  /// (unique, contiguous from 1), currency, and expiry before the RPC
  /// (fail-fast `PLT003`).
  Future<ServiceContract> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<ContractMilestoneInput> milestones,
    DateTime? offerExpiresAt,
  });

  /// Accepts an `offered` contract as the professional, then re-reads the row.
  Future<ServiceContract> acceptContract(String contractId);

  /// Cancels an `offered` contract (either participant), then re-reads.
  Future<ServiceContract> cancelContract(String contractId, {String? reason});

  /// Marks a `pending` milestone `completed` with an evidence path
  /// (professional), then re-reads the contract.
  Future<ServiceContract> completeMilestone({
    required String contractId,
    required String milestoneId,
    String? evidencePath,
  });

  /// Verifies a `completed` milestone (client, `verified`) or requests
  /// revision (`revision_requested`), then re-reads the contract.
  Future<ServiceContract> verifyMilestone({
    required String contractId,
    required String milestoneId,
    String action = 'verified',
  });

  /// Closes a contract once all milestones are verified, then re-reads.
  Future<ServiceContract> closeContract(String contractId);

  /// Fetches a single contract with ordered `milestones[]` + `events[]`.
  Future<ServiceContract> getContract(String contractId);

  /// Lists the caller's contracts with keyset pagination
  /// (`(created_at DESC, id DESC)`), optionally filtered by [status].
  Future<ServiceContractPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  });
}

/// Client-side milestone draft for `service_contract_offer`.
///
/// Carries the fields the offer RPC accepts per milestone; numbering is
/// assigned by position when [milestoneNumber] is omitted by the caller.
class ContractMilestoneInput {
  const ContractMilestoneInput({
    required this.milestoneNumber,
    required this.title,
    this.description,
    required this.amount,
    int? sortOrder,
  }) : sortOrder = sortOrder ?? (milestoneNumber - 1);

  /// 1-based position within the contract (unique, contiguous from 1).
  final int milestoneNumber;

  /// Milestone title (1–255 chars after trim).
  final String title;

  /// Optional milestone description (≤2000 chars).
  final String? description;

  /// Milestone amount (>0).
  final double amount;

  /// Display ordering (defaults to `milestoneNumber - 1`).
  final int sortOrder;

  /// Serializes to the `p_milestones` jsonb element shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'milestone_number': milestoneNumber.toString(),
    'title': title.trim(),
    'description': description?.trim().isEmpty ?? true
        ? null
        : description?.trim(),
    'amount': amount.toString(),
    'sort_order': sortOrder.toString(),
  };
}
