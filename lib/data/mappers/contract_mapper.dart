import 'package:hivorr/data/entities/contract_event.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/models/contract_envelopes_dto.dart';
import 'package:hivorr/data/models/contract_event_dto.dart';
import 'package:hivorr/data/models/contract_milestone_dto.dart';
import 'package:hivorr/data/models/service_contract_dto.dart';

/// Transformations between the service contract transport DTOs and the
/// pure-Dart domain entities (EP-03-10).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
abstract final class ContractMapper {
  /// Maps a `service_contracts` DTO into a domain [ServiceContract].
  static ServiceContract contractToEntity(ServiceContractDto dto) =>
      ServiceContract(
        id: dto.id,
        serviceListingId: dto.serviceListingId,
        clientEntityId: dto.clientEntityId,
        professionalEntityId: dto.professionalEntityId,
        status: dto.status,
        escrowId: dto.escrowId,
        totalAmount: dto.totalAmount,
        currencyCode: dto.currencyCode,
        offerExpiresAt: dto.offerExpiresAt,
        offeredAt: dto.offeredAt,
        acceptedAt: dto.acceptedAt,
        completedAt: dto.completedAt,
        closedAt: dto.closedAt,
        cancelledAt: dto.cancelledAt,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
        listingSlug: dto.listingSlug,
        listingTitle: dto.listingTitle,
        professionSlug: dto.professionSlug,
        professionName: dto.professionName,
        industrySlug: dto.industrySlug,
        industryName: dto.industryName,
      );

  /// Maps a `contract_milestones` DTO into a domain [ContractMilestone].
  static ContractMilestone milestoneToEntity(ContractMilestoneDto dto) =>
      ContractMilestone(
        id: dto.id,
        contractId: dto.contractId,
        escrowMilestoneId: dto.escrowMilestoneId,
        milestoneNumber: dto.milestoneNumber,
        title: dto.title,
        description: dto.description,
        amount: dto.amount,
        status: dto.status,
        evidencePath: dto.evidencePath,
        sortOrder: dto.sortOrder,
        completedAt: dto.completedAt,
        verifiedAt: dto.verifiedAt,
        releasedAt: dto.releasedAt,
        reviewPeriodExpiresAt: dto.reviewPeriodExpiresAt,
      );

  /// Maps a `contract_events` DTO into a domain [ContractEvent].
  static ContractEvent eventToEntity(ContractEventDto dto) => ContractEvent(
    id: dto.id,
    contractId: dto.contractId,
    entityId: dto.entityId,
    eventType: dto.eventType,
    fromStatus: dto.fromStatus,
    toStatus: dto.toStatus,
    actorId: dto.actorId,
    details: dto.details,
    createdAt: dto.createdAt,
  );

  /// Maps a `service_contract_get` envelope into a fully-hydrated
  /// [ServiceContract] (contract + milestones in server order + events in
  /// `created_at` order, verbatim).
  static ServiceContract detailEnvelopeToEntity(
    ContractDetailEnvelopeDto dto,
  ) {
    final ServiceContract base = contractToEntity(dto.contract);
    return ServiceContract(
      id: base.id,
      serviceListingId: base.serviceListingId,
      clientEntityId: base.clientEntityId,
      professionalEntityId: base.professionalEntityId,
      status: base.status,
      escrowId: base.escrowId,
      totalAmount: base.totalAmount,
      currencyCode: base.currencyCode,
      offerExpiresAt: base.offerExpiresAt,
      offeredAt: base.offeredAt,
      acceptedAt: base.acceptedAt,
      completedAt: base.completedAt,
      closedAt: base.closedAt,
      cancelledAt: base.cancelledAt,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      listingSlug: base.listingSlug,
      listingTitle: base.listingTitle,
      professionSlug: base.professionSlug,
      professionName: base.professionName,
      industrySlug: base.industrySlug,
      industryName: base.industryName,
      milestones: dto.milestones.map(milestoneToEntity).toList(growable: false),
      events: dto.events.map(eventToEntity).toList(growable: false),
    );
  }

  /// Maps a `service_contract_list_mine` envelope into domain [ServiceContract]
  /// headers (no milestones/events — use `get` for the full payload).
  static List<ServiceContract> listEnvelopeToEntities(
    ContractListEnvelopeDto dto,
  ) => dto.contracts.map(contractToEntity).toList(growable: false);
}

/// A keyset page of service contracts.
class ServiceContractPage {
  const ServiceContractPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  /// The page items (headers; milestones load via `get`).
  final List<ServiceContract> items;

  /// Whether further pages exist.
  final bool hasMore;

  /// Cursor for the next page, when [hasMore].
  final String? nextCursor;
}
