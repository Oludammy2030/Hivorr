import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/mappers/escrow_mapper.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/models/escrow_transaction_dto.dart';

import '../../../support/fakes/finance/fake_escrow_repository.dart'
    show seedMilestoneEntity;

void main() {
  EscrowDto escrowDto() => EscrowDto.fromJson(<String, dynamic>{
        'id': 'escrow-1',
        'financial_profile_id': 'profile-1',
        'payer_entity_id': 'entity-payer',
        'payee_entity_id': 'entity-payee',
        'currency_code': 'NGN',
        'total_amount': 50000,
        'released_amount': 15000,
        'refunded_amount': 0,
        'status': 'partially_released',
        'created_at': '2026-01-01T00:00:00.000Z',
        'external_reference': 'ORD-2026-000123',
        'funded_at': '2026-01-02T00:00:00.000Z',
      });

  EscrowMilestoneDto milestoneDto() => EscrowMilestoneDto.fromJson(
        <String, dynamic>{
          'id': 'ms-1',
          'escrow_id': 'escrow-1',
          'milestone_number': 1,
          'title': 'Design sign-off',
          'description': 'Deliver design',
          'amount': 25000,
          'status': 'completed',
          'sort_order': 1,
          'created_at': '2026-01-01T00:00:00.000Z',
          'completed_at': '2026-01-05T00:00:00.000Z',
        },
      );

  EscrowTransactionDto transactionDto() =>
      EscrowTransactionDto.fromJson(<String, dynamic>{
        'id': 'txn-1',
        'escrow_id': 'escrow-1',
        'type': 'release',
        'amount': 15000,
        'direction': 'out',
        'entity_id': 'entity-payee',
        'reference': 'RELEASE-1',
        'created_at': '2026-01-05T00:00:00.000Z',
      });

  group('EscrowMapper.escrowToEntity', () {
    test('maps the frozen column set including nullable release stamps', () {
      final entity = EscrowMapper.escrowToEntity(escrowDto());

      expect(entity.id, 'escrow-1');
      expect(entity.financialProfileId, 'profile-1');
      expect(entity.payerEntityId, 'entity-payer');
      expect(entity.payeeEntityId, 'entity-payee');
      expect(entity.currencyCode, 'NGN');
      expect(entity.totalAmount, 50000);
      expect(entity.releasedAmount, 15000);
      expect(entity.refundedAmount, 0);
      expect(entity.status, 'partially_released');
      expect(entity.externalReference, 'ORD-2026-000123');
      expect(entity.fundedAt, isNotNull);
      expect(entity.releasedAt, isNull);
    });
  });

  group('EscrowMapper.milestoneToEntity', () {
    test('maps milestone fields with nullable completion stamps', () {
      final entity = EscrowMapper.milestoneToEntity(milestoneDto());

      expect(entity.id, 'ms-1');
      expect(entity.escrowId, 'escrow-1');
      expect(entity.milestoneNumber, 1);
      expect(entity.title, 'Design sign-off');
      expect(entity.description, 'Deliver design');
      expect(entity.amount, 25000);
      expect(entity.status, 'completed');
      expect(entity.sortOrder, 1);
      expect(entity.completedAt, isNotNull);
      expect(entity.releasedAt, isNull);
      expect(entity.isCompleted, isTrue);
    });
  });

  group('EscrowMapper.transactionToEntity', () {
    test('maps transaction fields', () {
      final entity = EscrowMapper.transactionToEntity(transactionDto());

      expect(entity.id, 'txn-1');
      expect(entity.escrowId, 'escrow-1');
      expect(entity.type, 'release');
      expect(entity.amount, 15000);
      expect(entity.direction, 'out');
      expect(entity.entityId, 'entity-payee');
      expect(entity.reference, 'RELEASE-1');
    });
  });

  group('EscrowMapper.detailToEntity', () {
    test('maps the aggregate with unmodifiable child lists', () {
      final dto = EscrowDetailDto.fromJson(<String, dynamic>{
        'escrow': <String, dynamic>{
          'id': 'escrow-1',
          'status': 'funded',
        },
        'milestones': <dynamic>[
          <String, dynamic>{'id': 'ms-1', 'status': 'pending'},
        ],
        'transactions': <dynamic>[
          <String, dynamic>{'id': 'txn-1', 'type': 'release'},
        ],
      });

      final entity = EscrowMapper.detailToEntity(dto);

      expect(entity.escrow.id, 'escrow-1');
      expect(entity.milestones, hasLength(1));
      expect(entity.transactions, hasLength(1));
    });
  });

  group('EscrowMapper.entityToInput', () {
    test('converts milestone to create payload preserving ordering', () {
      final input = EscrowMapper.entityToInput(seedMilestoneEntity());

      expect(input, isA<EscrowMilestoneInput>());
      expect(input.milestoneNumber, 1);
      expect(input.title, 'Design sign-off');
      expect(input.amount, 50000.0);
      expect(input.sortOrder, 1);
      expect(input.description, isNull);
    });
  });

  group('EscrowMapper.escrowToEntity (vocabulary + edge cases)', () {
    test('passes through every one of the 7 server status codes', () {
      const List<String> codes = <String>[
        'created',
        'funded',
        'partially_released',
        'released',
        'refunded',
        'cancelled',
        'disputed',
      ];

      for (final String status in codes) {
        final Escrow entity = EscrowMapper.escrowToEntity(
          EscrowDto.fromJson(<String, dynamic>{
            'id': 'escrow-$status',
            'status': status,
            'created_at': '2026-01-01T00:00:00.000Z',
          }),
        );

        expect(entity.status, status);
        expect(entity.isDisputed, status == 'disputed');
        expect(entity.isActive, status == 'created' ||
            status == 'funded' ||
            status == 'partially_released');
      }
    });

    test('maps a null external_reference and null stamps to null', () {
      final Escrow entity = EscrowMapper.escrowToEntity(
        EscrowDto.fromJson(<String, dynamic>{
          'id': 'escrow-1',
          'status': 'funded',
          'created_at': '2026-01-01T00:00:00.000Z',
        }),
      );

      expect(entity.externalReference, isNull);
      expect(entity.fundedAt, isNull);
      expect(entity.releasedAt, isNull);
      expect(entity.refundedAt, isNull);
    });
  });

  group('EscrowMapper.detailToEntity (empty child lists)', () {
    test('never returns null child lists — empty milestones/transactions map '
        'to []', () {
      final EscrowDetail entity = EscrowMapper.detailToEntity(
        EscrowDetailDto.fromJson(<String, dynamic>{
          'escrow': <String, dynamic>{
            'id': 'escrow-1',
            'status': 'created',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        }),
      );

      expect(entity.milestones, isNotNull);
      expect(entity.milestones, isEmpty);
      expect(entity.transactions, isNotNull);
      expect(entity.transactions, isEmpty);
    });
  });

  group('EscrowMapper.milestoneToEntity (released + nullable description)', () {
    test('maps a released milestone with its release stamp', () {
      final EscrowMilestone entity = EscrowMapper.milestoneToEntity(
        EscrowMilestoneDto.fromJson(<String, dynamic>{
          'id': 'ms-2',
          'escrow_id': 'escrow-1',
          'milestone_number': 2,
          'title': 'Build',
          'amount': 25000,
          'status': 'released',
          'sort_order': 2,
          'created_at': '2026-01-01T00:00:00.000Z',
          'released_at': '2026-01-09T00:00:00.000Z',
        }),
      );

      expect(entity.isReleased, isTrue);
      expect(entity.isCompleted, isFalse);
      expect(entity.releasedAt, isNotNull);
      expect(entity.completedAt, isNull);
      expect(entity.description, isNull);
      expect(entity.amount, 25000);
    });
  });

  group('EscrowMapper.transactionToEntity (direction)', () {
    test('maps an inbound fund entry with isInbound', () {
      final EscrowTransaction entity = EscrowMapper.transactionToEntity(
        EscrowTransactionDto.fromJson(<String, dynamic>{
          'id': 'txn-2',
          'escrow_id': 'escrow-1',
          'type': 'fund',
          'amount': 50000,
          'direction': 'in',
          'entity_id': 'entity-payer',
          'reference': 'FUND-1',
          'created_at': '2026-01-01T00:00:00.000Z',
        }),
      );

      expect(entity.type, 'fund');
      expect(entity.isInbound, isTrue);
      expect(entity.isOutbound, isFalse);
      expect(entity.reference, 'FUND-1');
    });
  });

  group('EscrowMapper.entityToInput (numeric precision)', () {
    test('converts a partial-tolerance amount preserving precision', () {
      final EscrowMilestoneInput input = EscrowMapper.entityToInput(
        seedMilestoneEntity(
          milestoneNumber: 2,
          title: 'Build',
          amount: 34999.99,
          sortOrder: 2,
        ),
      );

      expect(input.milestoneNumber, 2);
      expect(input.title, 'Build');
      expect(input.amount, 34999.99);
      expect(input.sortOrder, 2);
    });
  });
}