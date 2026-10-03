import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/service_contract_remote_data_source.dart';
import 'package:hivorr/data/entities/contract_event.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';
import 'package:hivorr/data/models/contract_envelopes_dto.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';

/// Builds a `service_contract_get`-shaped detail map for fakes.
Map<String, dynamic> contractDetailRow({
  required String id,
  String status = 'offered',
  String clientId = 'client-1',
  String professionalId = 'pro-1',
  double total = 30000,
  String currency = 'NGN',
  List<Map<String, dynamic>>? milestones,
  List<Map<String, dynamic>>? events,
}) => <String, dynamic>{
  'contract': <String, dynamic>{
    'id': id,
    'service_listing_id': 'listing-1',
    'client_entity_id': clientId,
    'professional_entity_id': professionalId,
    'status': status,
    'escrow_id': null,
    'total_amount': total,
    'currency_code': currency,
    'listing_slug': 'plumbing-repair',
    'listing_title': 'Certified plumbing repair service',
    'profession_slug': 'plumber',
    'profession_name': 'Plumber',
  },
  'milestones':
      milestones ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'm1',
          'contract_id': id,
          'milestone_number': 1,
          'title': 'Inspection visit',
          'amount': 10000,
          'status': 'pending',
          'sort_order': 0,
        },
        <String, dynamic>{
          'id': 'm2',
          'contract_id': id,
          'milestone_number': 2,
          'title': 'Repair works',
          'amount': 10000,
          'status': 'pending',
          'sort_order': 1,
        },
        <String, dynamic>{
          'id': 'm3',
          'contract_id': id,
          'milestone_number': 3,
          'title': 'Testing and handover',
          'amount': 10000,
          'status': 'pending',
          'sort_order': 2,
        },
      ],
  'events':
      events ??
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'e1',
          'contract_id': id,
          'event_type': 'offered',
          'from_status': null,
          'to_status': 'offered',
          'created_at': '2026-09-26T10:00:00.000Z',
        },
      ],
};

/// In-memory fake for [ServiceContractRemoteDataSource] (EP-03-10 tests).
class FakeServiceContractRemoteDataSource
    implements ServiceContractRemoteDataSource {
  FakeServiceContractRemoteDataSource({List<Map<String, dynamic>>? seed})
    : _rows = <Map<String, dynamic>>[...?seed];

  final List<Map<String, dynamic>> _rows;

  int offerCalls = 0;
  int acceptCalls = 0;
  int cancelCalls = 0;
  int completeCalls = 0;
  int verifyCalls = 0;
  int closeCalls = 0;
  int getCalls = 0;
  int listCalls = 0;
  String? lastStatus;
  String? lastCursor;
  String? lastVerifyAction;

  Map<String, dynamic> _find(String id) => _rows.firstWhere(
    (Map<String, dynamic> e) =>
        (e['contract'] as Map<String, dynamic>)['id'] == id,
    orElse: () => throw StateError('not found: $id'),
  );

  static Map<String, dynamic> _contractOf(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row['contract'] as Map<String, dynamic>);

  @override
  Future<ContractOfferEnvelopeDto> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<Map<String, dynamic>> milestones,
    String? offerExpiresAt,
  }) async {
    offerCalls++;
    final Map<String, dynamic> row = contractDetailRow(
      id: 'contract-${_rows.length + 1}',
      total: totalAmount,
      currency: currencyCode,
      milestones: milestones
          .map(
            (m) => <String, dynamic>{
              'id': 'm-${_rows.length + 1}-${m['milestone_number']}',
              'contract_id': 'contract-${_rows.length + 1}',
              'milestone_number': int.parse(m['milestone_number'] as String),
              'title': m['title'],
              'description': m['description'],
              'amount': double.parse(m['amount'] as String),
              'status': 'pending',
              'sort_order': int.parse(m['sort_order'] as String),
            },
          )
          .toList(),
    );
    _rows.insert(0, row);
    return ContractOfferEnvelopeDto.fromJson(<String, dynamic>{
      'contract': row['contract'],
      'milestones': row['milestones'],
    });
  }

  @override
  Future<Map<String, dynamic>> acceptContract(String contractId) async {
    acceptCalls++;
    final Map<String, dynamic> row = _find(contractId);
    _contractOf(row)['status'] = 'active';
    return <String, dynamic>{'id': contractId, 'status': 'active'};
  }

  @override
  Future<Map<String, dynamic>> cancelContract(
    String contractId, {
    String? reason,
  }) async {
    cancelCalls++;
    final Map<String, dynamic> row = _find(contractId);
    _contractOf(row)['status'] = 'cancelled';
    return <String, dynamic>{'id': contractId, 'status': 'cancelled'};
  }

  @override
  Future<Map<String, dynamic>> completeMilestone({
    required String milestoneId,
    String? evidencePath,
  }) async {
    completeCalls++;
    for (final row in _rows) {
      final List<dynamic> milestones = row['milestones'] as List<dynamic>;
      for (final m in milestones) {
        final Map<String, dynamic> milestone = m as Map<String, dynamic>;
        if (milestone['id'] == milestoneId) {
          milestone['status'] = 'completed';
          if (evidencePath != null) {
            milestone['evidence_path'] = evidencePath;
          }
          return <String, dynamic>{'id': milestoneId, 'status': 'completed'};
        }
      }
    }
    throw StateError('not found: $milestoneId');
  }

  @override
  Future<Map<String, dynamic>> verifyMilestone({
    required String milestoneId,
    String action = 'verified',
  }) async {
    verifyCalls++;
    lastVerifyAction = action;
    for (final row in _rows) {
      final List<dynamic> milestones = row['milestones'] as List<dynamic>;
      for (final m in milestones) {
        final Map<String, dynamic> milestone = m as Map<String, dynamic>;
        if (milestone['id'] == milestoneId) {
          milestone['status'] = action == 'verified'
              ? 'verified'
              : 'pending';
          return <String, dynamic>{
            'id': milestoneId,
            'status': milestone['status'],
          };
        }
      }
    }
    throw StateError('not found: $milestoneId');
  }

  @override
  Future<Map<String, dynamic>> closeContract(String contractId) async {
    closeCalls++;
    final Map<String, dynamic> row = _find(contractId);
    _contractOf(row)['status'] = 'closed';
    return <String, dynamic>{'id': contractId, 'status': 'closed'};
  }

  @override
  Future<ContractDetailEnvelopeDto> getContract(String contractId) async {
    getCalls++;
    return ContractDetailEnvelopeDto.fromJson(_find(contractId));
  }

  @override
  Future<ContractListEnvelopeDto> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    lastStatus = status;
    lastCursor = cursor;
    final List<Map<String, dynamic>> filtered = status == null
        ? List<Map<String, dynamic>>.from(_rows)
        : _rows
              .where(
                (e) =>
                    (_contractOf(e)['status'] as String?) == status,
              )
              .toList();
    final List<Map<String, dynamic>> items = filtered.take(limit).toList();
    return ContractListEnvelopeDto.fromJson(<String, dynamic>{
      'items': items
          .map((e) => _contractOf(e))
          .toList(growable: false),
      'has_more': filtered.length > items.length,
      'next_cursor': filtered.length > items.length
          ? _contractOf(items.last)['id']
          : null,
    });
  }
}

/// In-memory fake for [ServiceContractRepository] (EP-03-10 widget tests).
class FakeServiceContractRepository implements ServiceContractRepository {
  FakeServiceContractRepository({List<ServiceContract>? seed})
    : _rows = <ServiceContract>[...?seed];

  final List<ServiceContract> _rows;

  int listCalls = 0;
  String? lastStatus;

  /// When set, [getContract] throws this instead of returning a row (e.g. a
  /// `PLT004` [ApiException] for not-found detail tests).
  ApiException? getContractError;

  int offerCalls = 0;
  int acceptCalls = 0;
  int completeCalls = 0;
  int verifyCalls = 0;
  String? lastVerifyAction;

  static ServiceContract contract({
    required String id,
    String status = 'offered',
    String clientId = 'client-1',
    String professionalId = 'pro-1',
    List<ContractMilestone>? milestones,
  }) => ServiceContract(
    id: id,
    serviceListingId: 'listing-1',
    clientEntityId: clientId,
    professionalEntityId: professionalId,
    status: status,
    totalAmount: 30000,
    currencyCode: 'NGN',
    milestones:
        milestones ??
        const <ContractMilestone>[
          ContractMilestone(
            id: 'm1',
            contractId: 'c1',
            milestoneNumber: 1,
            title: 'Inspection visit',
            amount: 10000,
            status: 'pending',
            sortOrder: 0,
          ),
          ContractMilestone(
            id: 'm2',
            contractId: 'c1',
            milestoneNumber: 2,
            title: 'Repair works',
            amount: 10000,
            status: 'pending',
            sortOrder: 1,
          ),
          ContractMilestone(
            id: 'm3',
            contractId: 'c1',
            milestoneNumber: 3,
            title: 'Testing and handover',
            amount: 10000,
            status: 'pending',
            sortOrder: 2,
          ),
        ],
    events: const <ContractEvent>[
      ContractEvent(id: 'e1', contractId: 'c1', eventType: 'offered'),
    ],
  );

  @override
  Future<ServiceContract> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<ContractMilestoneInput> milestones,
    DateTime? offerExpiresAt,
  }) async {
    offerCalls++;
    final ServiceContract created = contract(
      id: 'contract-${_rows.length + 1}',
    );
    _rows.insert(0, created);
    return created;
  }

  @override
  Future<ServiceContract> acceptContract(String contractId) async {
    acceptCalls++;
    return _replaceStatus(contractId, 'active');
  }

  @override
  Future<ServiceContract> cancelContract(
    String contractId, {
    String? reason,
  }) async => _replaceStatus(contractId, 'cancelled');

  @override
  Future<ServiceContract> completeMilestone({
    required String contractId,
    required String milestoneId,
    String? evidencePath,
  }) async {
    completeCalls++;
    return _replaceMilestoneStatus(contractId, milestoneId, 'completed');
  }

  @override
  Future<ServiceContract> verifyMilestone({
    required String contractId,
    required String milestoneId,
    String action = 'verified',
  }) async {
    verifyCalls++;
    lastVerifyAction = action;
    return _replaceMilestoneStatus(
      contractId,
      milestoneId,
      action == 'verified' ? 'verified' : 'pending',
    );
  }

  @override
  Future<ServiceContract> closeContract(String contractId) async =>
      _replaceStatus(contractId, 'closed');

  @override
  Future<ServiceContract> getContract(String contractId) async {
    final ApiException? error = getContractError;
    if (error != null) throw error;
    try {
      return _rows.firstWhere((e) => e.id == contractId);
    } on StateError {
      // Mirrors the server `PLT004` oracle (identical for foreign/unknown).
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Contract not found.',
        code: 'PLT004',
      );
    }
  }

  @override
  Future<ServiceContractPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    lastStatus = status;
    final List<ServiceContract> filtered = status == null
        ? List<ServiceContract>.from(_rows)
        : _rows.where((e) => e.status == status).toList();
    return ServiceContractPage(
      items: filtered.take(limit).toList(),
      hasMore: false,
    );
  }

  ServiceContract _replaceStatus(String contractId, String status) {
    final int index = _rows.indexWhere((e) => e.id == contractId);
    final ServiceContract current = _rows[index];
    final ServiceContract updated = ServiceContract(
      id: current.id,
      serviceListingId: current.serviceListingId,
      clientEntityId: current.clientEntityId,
      professionalEntityId: current.professionalEntityId,
      status: status,
      escrowId: current.escrowId,
      totalAmount: current.totalAmount,
      currencyCode: current.currencyCode,
      milestones: current.milestones,
      events: current.events,
    );
    _rows[index] = updated;
    return updated;
  }

  ServiceContract _replaceMilestoneStatus(
    String contractId,
    String milestoneId,
    String status,
  ) {
    final int index = _rows.indexWhere((e) => e.id == contractId);
    final ServiceContract current = _rows[index];
    final ServiceContract updated = ServiceContract(
      id: current.id,
      serviceListingId: current.serviceListingId,
      clientEntityId: current.clientEntityId,
      professionalEntityId: current.professionalEntityId,
      status: current.status,
      escrowId: current.escrowId,
      totalAmount: current.totalAmount,
      currencyCode: current.currencyCode,
      milestones: current.milestones
          .map(
            (m) => m.id == milestoneId ? m.copyWithStatus(status) : m,
          )
          .toList(growable: false),
      events: current.events,
    );
    _rows[index] = updated;
    return updated;
  }
}
