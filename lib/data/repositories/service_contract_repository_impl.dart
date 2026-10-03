// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/service_contract_remote_data_source.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';
import 'package:hivorr/data/models/contract_envelopes_dto.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';

/// Default implementation of [ServiceContractRepository].
///
/// Implements the server-authoritative engagement flow (EP-03-10 §7): writes
/// via the client-callable contract RPCs with client-side fail-fast mirrors of
/// the frozen CHECK constraints (title 1–255, description ≤2000, amounts >0,
/// unique contiguous numbering from 1, `sum == total` within `0.01`, currency
/// vocab, expiry in future), then re-reads the authoritative row via
/// `service_contract_get`. The server remains the single authority; the
/// repository mirrors the codes for fail-fast UX only. Never writes contract
/// tables directly and never references service-role-only transitions
/// (`AGENT.md` Rule 4).
class ServiceContractRepositoryImpl implements ServiceContractRepository {
  ServiceContractRepositoryImpl({
    required ServiceContractRemoteDataSource remote,
  }) : _remote = remote;

  final ServiceContractRemoteDataSource _remote;

  /// Active currency subset (`financial_supported_currencies` active rows).
  static const Set<String> currencies = <String>{
    'NGN',
    'GHS',
    'USD',
    'GBP',
  };

  /// Contract list status filter vocabulary (client may only filter).
  static const Set<String> statuses = <String>{
    'draft',
    'offered',
    'active',
    'completed',
    'closed',
    'cancelled',
    'disputed',
  };

  /// Verify actions accepted by `service_contract_verify_milestone`.
  static const Set<String> verifyActions = <String>{
    'verified',
    'revision_requested',
  };

  @override
  Future<ServiceContract> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<ContractMilestoneInput> milestones,
    DateTime? offerExpiresAt,
  }) async {
    _requireNonEmpty(serviceListingId, 'serviceListingId');
    if (totalAmount <= 0) _fail('Total amount must be greater than zero.');
    _requireCurrency(currencyCode);
    _requireMilestones(milestones);
    _requireMilestoneSum(milestones: milestones, totalAmount: totalAmount);
    if (offerExpiresAt != null &&
        !offerExpiresAt.isAfter(DateTime.now())) {
      _fail('Offer expiry must be in the future.');
    }
    final ContractOfferEnvelopeDto envelope = await _remote.offerContract(
      serviceListingId: serviceListingId,
      totalAmount: totalAmount,
      currencyCode: currencyCode,
      milestones: milestones.map((e) => e.toJson()).toList(growable: false),
      offerExpiresAt: offerExpiresAt?.toUtc().toIso8601String(),
    );
    // Re-read the authoritative row (server holds timestamps and the
    // `offered` event; the offer envelope carries `{contract, milestones[]}`
    // without events).
    return getContract(envelope.contract.id);
  }

  @override
  Future<ServiceContract> acceptContract(String contractId) async {
    _requireNonEmpty(contractId, 'contractId');
    await _remote.acceptContract(contractId);
    return getContract(contractId);
  }

  @override
  Future<ServiceContract> cancelContract(
    String contractId, {
    String? reason,
  }) async {
    _requireNonEmpty(contractId, 'contractId');
    await _remote.cancelContract(contractId, reason: reason);
    return getContract(contractId);
  }

  @override
  Future<ServiceContract> completeMilestone({
    required String contractId,
    required String milestoneId,
    String? evidencePath,
  }) async {
    _requireNonEmpty(contractId, 'contractId');
    _requireNonEmpty(milestoneId, 'milestoneId');
    await _remote.completeMilestone(
      milestoneId: milestoneId,
      evidencePath: evidencePath,
    );
    return getContract(contractId);
  }

  @override
  Future<ServiceContract> verifyMilestone({
    required String contractId,
    required String milestoneId,
    String action = 'verified',
  }) async {
    _requireNonEmpty(contractId, 'contractId');
    _requireNonEmpty(milestoneId, 'milestoneId');
    if (!verifyActions.contains(action)) {
      _fail('Invalid verify action: $action.');
    }
    await _remote.verifyMilestone(milestoneId: milestoneId, action: action);
    return getContract(contractId);
  }

  @override
  Future<ServiceContract> closeContract(String contractId) async {
    _requireNonEmpty(contractId, 'contractId');
    await _remote.closeContract(contractId);
    return getContract(contractId);
  }

  @override
  Future<ServiceContract> getContract(String contractId) async {
    _requireNonEmpty(contractId, 'contractId');
    final ContractDetailEnvelopeDto dto = await _remote.getContract(contractId);
    return ContractMapper.detailEnvelopeToEntity(dto);
  }

  @override
  Future<ServiceContractPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    if (status != null) _requireInVocabulary(status, statuses, 'status');
    _requireLimit(limit);
    final ContractListEnvelopeDto dto = await _remote.listMine(
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return ServiceContractPage(
      items: ContractMapper.listEnvelopeToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  void _requireMilestones(List<ContractMilestoneInput> milestones) {
    if (milestones.isEmpty) _fail('At least one milestone is required.');
    final Set<int> seen = <int>{};
    for (int i = 0; i < milestones.length; i++) {
      final ContractMilestoneInput m = milestones[i];
      if (m.milestoneNumber < 1) {
        _fail('Milestone number must be 1 or greater.');
      }
      if (!seen.add(m.milestoneNumber)) {
        throw const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'Duplicate milestone number in request.',
          code: 'PLT005',
        );
      }
      if (m.title.trim().isEmpty || m.title.trim().length > 255) {
        _fail('Milestone title must be 1 to 255 characters.');
      }
      if (m.description != null && m.description!.trim().length > 2000) {
        _fail('Milestone description must be at most 2000 characters.');
      }
      if (m.amount <= 0) {
        _fail('Milestone amount must be greater than zero.');
      }
    }
    final List<int> ordered = seen.toList()..sort();
    for (int i = 0; i < ordered.length; i++) {
      if (ordered[i] != i + 1) {
        throw const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'Milestone numbers must be contiguous from 1.',
          code: 'PLT005',
        );
      }
    }
  }

  void _requireMilestoneSum({
    required List<ContractMilestoneInput> milestones,
    required double totalAmount,
  }) {
    final double sum = milestones.fold(
      0.0,
      (double acc, ContractMilestoneInput m) => acc + m.amount,
    );
    if ((sum - totalAmount).abs() > 0.01) {
      _fail('Milestone amounts must sum to total amount.');
    }
  }

  void _requireCurrency(String currency) {
    if (!currencies.contains(currency)) {
      _fail('Invalid currency code.');
    }
  }

  void _requireLimit(int limit) {
    if (limit < 1 || limit > 100) {
      _fail('Limit must be between 1 and 100.');
    }
  }

  static void _fail(String message) {
    throw ApiException(
      kind: ApiExceptionKind.validation,
      message: message,
      code: 'PLT003',
    );
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      _fail('$field is required.');
    }
  }

  static void _requireInVocabulary(
    String value,
    Set<String> vocabulary,
    String field,
  ) {
    if (!vocabulary.contains(value)) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid $field value: $value.',
        code: 'PLT003',
      );
    }
  }
}
