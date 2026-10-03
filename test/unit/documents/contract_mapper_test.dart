import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/contract_event.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';
import 'package:hivorr/data/models/contract_envelopes_dto.dart';

void main() {
  Map<String, dynamic> detailJson() => <String, dynamic>{
    'contract': <String, dynamic>{
      'id': 'c1',
      'service_listing_id': 'listing-1',
      'client_entity_id': 'client-1',
      'professional_entity_id': 'pro-1',
      'status': 'active',
      'escrow_id': null,
      'total_amount': 30000,
      'currency_code': 'NGN',
      'listing_slug': 'plumbing-repair',
      'listing_title': 'Certified plumbing repair service',
      'profession_slug': 'plumber',
      'profession_name': 'Plumber',
    },
    'milestones': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'm2',
        'contract_id': 'c1',
        'milestone_number': 2,
        'title': 'Repair works',
        'amount': 10000,
        'status': 'completed',
        'sort_order': 1,
      },
      <String, dynamic>{
        'id': 'm1',
        'contract_id': 'c1',
        'milestone_number': 1,
        'title': 'Inspection visit',
        'amount': 10000,
        'status': 'verified',
        'sort_order': 0,
      },
    ],
    'events': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'e1',
        'contract_id': 'c1',
        'event_type': 'offered',
        'to_status': 'offered',
        'created_at': '2026-09-26T10:00:00.000Z',
      },
      <String, dynamic>{
        'id': 'e2',
        'contract_id': 'c1',
        'event_type': 'accepted',
        'from_status': 'offered',
        'to_status': 'active',
        'created_at': '2026-09-26T11:00:00.000Z',
      },
    ],
  };

  group('ContractMapper.detailEnvelopeToEntity', () {
    test('hydrates contract with join fields, milestones, and events', () {
      final dto = ContractDetailEnvelopeDto.fromJson(detailJson());
      final ServiceContract entity = ContractMapper.detailEnvelopeToEntity(
        dto,
      );
      expect(entity.id, 'c1');
      expect(entity.status, 'active');
      expect(entity.isActive, isTrue);
      expect(entity.listingTitle, 'Certified plumbing repair service');
      expect(entity.professionName, 'Plumber');
      expect(entity.milestones, hasLength(2));
      expect(entity.events, hasLength(2));
      // Server order preserved verbatim (no client re-sort here — the DTO
      // carries server order; the adapter owns display ordering).
      expect(entity.milestones.first.id, 'm2');
    });

    test('allMilestonesVerified derives correctly', () {
      final dto = ContractDetailEnvelopeDto.fromJson(detailJson());
      final ServiceContract entity = ContractMapper.detailEnvelopeToEntity(
        dto,
      );
      expect(entity.allMilestonesVerified, isFalse);
      expect(entity.unverifiedCount, 1);
    });
  });

  group('ContractMapper.listEnvelopeToEntities', () {
    test('maps headers without milestones', () {
      final dto = ContractListEnvelopeDto.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'c1',
            'service_listing_id': 'listing-1',
            'client_entity_id': 'client-1',
            'professional_entity_id': 'pro-1',
            'status': 'offered',
            'total_amount': 30000,
            'currency_code': 'NGN',
          },
        ],
        'has_more': true,
        'next_cursor': 'c1',
      });
      final List<ServiceContract> entities =
          ContractMapper.listEnvelopeToEntities(dto);
      expect(entities, hasLength(1));
      expect(entities.first.milestones, isEmpty);
      expect(entities.first.isOffered, isTrue);
      expect(dto.hasMore, isTrue);
      expect(dto.nextCursor, 'c1');
    });
  });

  group('ServiceContract view-intent helpers', () {
    ServiceContract contract() => const ServiceContract(
      id: 'c1',
      serviceListingId: 'listing-1',
      clientEntityId: 'client-1',
      professionalEntityId: 'pro-1',
      status: 'offered',
      totalAmount: 30000,
      currencyCode: 'NGN',
    );

    test('canAccept is professional-only on offered', () {
      expect(contract().canAccept('pro-1'), isTrue);
      expect(contract().canAccept('client-1'), isFalse);
      expect(contract().canAccept('stranger'), isFalse);
    });

    test('ContractMilestone status getters', () {
      const m = ContractMilestone(
        id: 'm1',
        contractId: 'c1',
        milestoneNumber: 1,
        title: 'Work',
        amount: 100,
        status: 'verified',
        sortOrder: 0,
      );
      expect(m.isVerified, isTrue);
      expect(m.isPending, isFalse);
      expect(m.copyWithStatus('pending').isPending, isTrue);
    });

    test('ContractEvent carries vocabulary verbatim', () {
      const e = ContractEvent(
        id: 'e1',
        contractId: 'c1',
        eventType: 'revision_requested',
      );
      expect(e.eventType, 'revision_requested');
    });
  });
}
