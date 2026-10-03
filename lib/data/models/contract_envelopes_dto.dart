import 'package:hivorr/data/models/contract_event_dto.dart';
import 'package:hivorr/data/models/contract_milestone_dto.dart';
import 'package:hivorr/data/models/service_contract_dto.dart';

/// Envelope for `service_contract_offer` (EP-03-10).
///
/// `data` shape: `{contract, milestones[]}`. The `contract` payload carries the
/// created row; `milestones` carries the created `pending` rows in request
/// order.
class ContractOfferEnvelopeDto {
  const ContractOfferEnvelopeDto({
    required this.contract,
    required this.milestones,
  });

  factory ContractOfferEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? contractRaw = json['contract'];
    final Object? milestonesRaw = json['milestones'];
    return ContractOfferEnvelopeDto(
      contract: ServiceContractDto.fromJson(
        contractRaw is Map<String, dynamic>
            ? contractRaw
            : const <String, dynamic>{},
      ),
      milestones: milestonesRaw is List
          ? milestonesRaw
                .whereType<Map<String, dynamic>>()
                .map(ContractMilestoneDto.fromJson)
                .toList(growable: false)
          : const <ContractMilestoneDto>[],
    );
  }

  final ServiceContractDto contract;
  final List<ContractMilestoneDto> milestones;
}

/// Envelope for `service_contract_get` (EP-03-10).
///
/// `data` shape: `{contract, milestones[], events[]}`. The `contract` payload
/// includes the listing/profession/industry join fields; `milestones` is
/// ordered `(sort_order, milestone_number)` and `events` by `created_at`
/// server-side.
class ContractDetailEnvelopeDto {
  const ContractDetailEnvelopeDto({
    required this.contract,
    required this.milestones,
    required this.events,
  });

  factory ContractDetailEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? contractRaw = json['contract'];
    final Object? milestonesRaw = json['milestones'];
    final Object? eventsRaw = json['events'];
    return ContractDetailEnvelopeDto(
      contract: ServiceContractDto.fromJson(
        contractRaw is Map<String, dynamic>
            ? contractRaw
            : const <String, dynamic>{},
      ),
      milestones: milestonesRaw is List
          ? milestonesRaw
                .whereType<Map<String, dynamic>>()
                .map(ContractMilestoneDto.fromJson)
                .toList(growable: false)
          : const <ContractMilestoneDto>[],
      events: eventsRaw is List
          ? eventsRaw
                .whereType<Map<String, dynamic>>()
                .map(ContractEventDto.fromJson)
                .toList(growable: false)
          : const <ContractEventDto>[],
    );
  }

  final ServiceContractDto contract;
  final List<ContractMilestoneDto> milestones;
  final List<ContractEventDto> events;
}

/// Envelope for `service_contract_list_mine` (EP-03-10).
///
/// `data` shape: `{items: ServiceContract[] (no milestones/events),
/// has_more, next_cursor}`. Keyset is `(created_at DESC, id DESC)`; an
/// unknown/foreign cursor yields an empty page (no oracle).
class ContractListEnvelopeDto {
  const ContractListEnvelopeDto({
    required this.contracts,
    required this.hasMore,
    this.nextCursor,
  });

  factory ContractListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    return ContractListEnvelopeDto(
      contracts: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ServiceContractDto.fromJson)
                .toList(growable: false)
          : const <ServiceContractDto>[],
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<ServiceContractDto> contracts;
  final bool hasMore;
  final String? nextCursor;
}

/// Envelope for `service_contract_list_mine` items decoded without milestones.
class ServiceContractPageDto {
  const ServiceContractPageDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  factory ServiceContractPageDto.fromJson(Map<String, dynamic> json) =>
      ServiceContractPageDto(
        items:
            (json['items'] is List
                    ? (json['items'] as List)
                          .whereType<Map<String, dynamic>>()
                          .map(ServiceContractDto.fromJson)
                          .toList(growable: false)
                    : const <ServiceContractDto>[]),
        hasMore: (json['has_more'] as bool?) ?? false,
        nextCursor: json['next_cursor'] as String?,
      );

  final List<ServiceContractDto> items;
  final bool hasMore;
  final String? nextCursor;
}
