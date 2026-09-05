import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/models/escrow_transaction_dto.dart';

void main() {
  group('EscrowDto.fromJson', () {
    test('parses the frozen migration column set', () {
      final dto = EscrowDto.fromJson(<String, dynamic>{
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
        'released_at': null,
        'refunded_at': null,
      });

      expect(dto.id, 'escrow-1');
      expect(dto.financialProfileId, 'profile-1');
      expect(dto.payerEntityId, 'entity-payer');
      expect(dto.payeeEntityId, 'entity-payee');
      expect(dto.currencyCode, 'NGN');
      expect(dto.totalAmount, 50000);
      expect(dto.releasedAmount, 15000);
      expect(dto.status, 'partially_released');
      expect(dto.externalReference, 'ORD-2026-000123');
      expect(dto.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(dto.fundedAt, DateTime.parse('2026-01-02T00:00:00.000Z'));
      expect(dto.releasedAt, isNull);
    });

    test('coerces numeric strings and tolerates missing optional fields', () {
      final dto = EscrowDto.fromJson(<String, dynamic>{
        'id': 'escrow-2',
        'total_amount': '25000.50',
        'status': 'created',
        'created_at': '2026-02-01T00:00:00.000Z',
      });

      expect(dto.totalAmount, closeTo(25000.50, 0.001));
      expect(dto.status, 'created');
      expect(dto.externalReference, isNull);
      expect(dto.fundedAt, isNull);
    });
  });

  group('EscrowMilestoneDto.fromJson', () {
    test('parses milestone fields incl. status and ordering', () {
      final dto = EscrowMilestoneDto.fromJson(<String, dynamic>{
        'id': 'ms-1',
        'escrow_id': 'escrow-1',
        'milestone_number': 2,
        'title': 'Build',
        'description': 'Deliver build',
        'amount': 25000,
        'status': 'completed',
        'sort_order': 2,
        'created_at': '2026-01-01T00:00:00.000Z',
        'completed_at': '2026-01-05T00:00:00.000Z',
        'released_at': null,
      });

      expect(dto.milestoneNumber, 2);
      expect(dto.title, 'Build');
      expect(dto.amount, 25000);
      expect(dto.status, 'completed');
      expect(dto.sortOrder, 2);
      expect(dto.completedAt, isNotNull);
      expect(dto.releasedAt, isNull);
    });
  });

  group('EscrowTransactionDto.fromJson', () {
    test('parses direction and amount', () {
      final dto = EscrowTransactionDto.fromJson(<String, dynamic>{
        'id': 'txn-1',
        'escrow_id': 'escrow-1',
        'type': 'release',
        'amount': 25000,
        'direction': 'out',
        'entity_id': 'entity-payee',
        'reference': 'RELEASE-1',
        'created_at': '2026-01-05T00:00:00.000Z',
      });

      expect(dto.type, 'release');
      expect(dto.amount, 25000);
      expect(dto.direction, 'out');
      expect(dto.entityId, 'entity-payee');
    });
  });

  group('EscrowDetailDto.fromJson', () {
    test('parses escrow + milestones + transactions', () {
      final dto = EscrowDetailDto.fromJson(<String, dynamic>{
        'escrow': <String, dynamic>{
          'id': 'escrow-1',
          'status': 'funded',
        },
        'milestones': <dynamic>[
          <String, dynamic>{'id': 'ms-1', 'status': 'pending'},
          <String, dynamic>{'id': 'ms-2', 'status': 'released'},
        ],
        'transactions': <dynamic>[
          <String, dynamic>{'id': 'txn-1', 'type': 'release'},
        ],
      });

      expect(dto.escrow.id, 'escrow-1');
      expect(dto.milestones, hasLength(2));
      expect(dto.transactions, hasLength(1));
    });

    test('tolerates a missing transactions key (frozen read model)', () {
      final dto = EscrowDetailDto.fromJson(<String, dynamic>{
        'escrow': <String, dynamic>{'id': 'escrow-1'},
        'milestones': <dynamic>[],
      });

      expect(dto.transactions, isEmpty);
    });

    test('falls back when escrow object is absent', () {
      final dto = EscrowDetailDto.fromJson(<String, dynamic>{});
      expect(dto.escrow.id, '');
      expect(dto.milestones, isEmpty);
      expect(dto.transactions, isEmpty);
    });
  });

  group('EscrowMilestoneInput.toJson', () {
    test('serializes the financial_escrow_create jsonb keys', () {
      const input = EscrowMilestoneInput(
        milestoneNumber: 1,
        title: 'Design',
        amount: 30000,
      );

      expect(input.toJson(), <String, dynamic>{
        'milestone_number': 1,
        'title': 'Design',
        'description': null,
        'amount': 30000.0,
        'sort_order': 1,
      });
    });

    test('uses explicit sort_order over milestone_number', () {
      const input = EscrowMilestoneInput(
        milestoneNumber: 1,
        title: 'Design',
        amount: 30000,
        sortOrder: 5,
      );

      expect(input.toJson()['sort_order'], 5);
    });
  });
}