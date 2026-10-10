import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/mappers/earnings_mapper.dart';
import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';

void main() {
  Map<String, dynamic> summaryJson() => <String, dynamic>{
    'currency_code': 'NGN',
    'available_balance': 50000,
    'held_balance': 20000,
    'pending_balance': 0,
    'lifetime_earned': 120000,
    'release_count': 3,
    'completed_contracts': 2,
    'total_withdrawn': 40000,
    'frozen_count': 1,
    'monthly': <dynamic>[
      <String, dynamic>{
        'month': '2026-09-01',
        'earned': 40000,
        'count': 1,
      },
      <String, dynamic>{'month': '2026-10-01', 'earned': 0, 'count': 0},
    ],
  };

  Map<String, dynamic> transactionJson() => <String, dynamic>{
    'id': 'tx-1',
    'transaction_type': 'escrow_release',
    'currency_code': 'NGN',
    'amount': 10000,
    'direction': 'in',
    'source_entity_id': 'entity-client',
    'destination_entity_id': 'entity-pro',
    'reference_type': 'escrow',
    'reference_id': 'escrow-1',
    'description': 'Milestone released',
    'created_at': '2026-10-01T12:00:00.000Z',
    'contract_id': 'contract-1',
    'contract_status': 'active',
    'escrow_status': 'funded',
  };

  group('EarningsMapper.summaryToEntity', () {
    test('maps server aggregates verbatim including month buckets', () {
      final EarningsSummary entity = EarningsMapper.summaryToEntity(
        EarningsSummaryDto.fromJson(summaryJson()),
      );

      expect(entity.currencyCode, 'NGN');
      expect(entity.availableBalance, 50000);
      expect(entity.heldBalance, 20000);
      expect(entity.lifetimeEarned, 120000);
      expect(entity.releaseCount, 3);
      expect(entity.completedContracts, 2);
      expect(entity.totalWithdrawn, 40000);
      expect(entity.frozenCount, 1);
      expect(entity.hasEarnings, isTrue);
      expect(entity.hasFrozen, isTrue);
      expect(entity.monthly, hasLength(2));
      expect(entity.monthly.first.month, DateTime(2026, 9));
      expect(entity.monthly.first.earned, 40000);
      expect(entity.monthly.first.releaseCount, 1);
    });

    test('defaults missing numerics to zero and missing months to empty', () {
      final EarningsSummary entity = EarningsMapper.summaryToEntity(
        EarningsSummaryDto.fromJson(<String, dynamic>{}),
      );

      expect(entity.currencyCode, isEmpty);
      expect(entity.lifetimeEarned, 0);
      expect(entity.monthly, isEmpty);
      expect(entity.hasEarnings, isFalse);
      expect(entity.hasFrozen, isFalse);
    });
  });

  group('EarningsMapper.transactionToEntity', () {
    test('maps the ledger projection including attribution', () {
      final EarningsTransaction entity = EarningsMapper.transactionToEntity(
        EarningsTransactionDto.fromJson(transactionJson()),
      );

      expect(entity.id, 'tx-1');
      expect(entity.type, 'escrow_release');
      expect(entity.amount, 10000);
      expect(entity.isInbound, isTrue);
      expect(entity.isOutbound, isFalse);
      expect(entity.isDisputed, isFalse);
      expect(entity.isEarnedRelease, isTrue);
      expect(entity.contractId, 'contract-1');
      expect(entity.contractStatus, 'active');
      expect(entity.escrowStatus, 'funded');
    });

    test('flags disputed rows and outbound direction', () {
      final EarningsTransaction entity = EarningsMapper.transactionToEntity(
        EarningsTransactionDto.fromJson(<String, dynamic>{
          ...transactionJson(),
          'direction': 'out',
          'type': 'withdrawal',
          'escrow_status': 'disputed',
        }),
      );

      expect(entity.isInbound, isFalse);
      expect(entity.isOutbound, isTrue);
      expect(entity.isDisputed, isTrue);
      expect(entity.isEarnedRelease, isFalse);
    });
  });

  group('EarningsMapper.pageToEntity', () {
    test('maps items in order and preserves the cursor contract', () {
      final EarningsTransactionPage page = EarningsMapper.pageToEntity(
        EarningsTransactionPageDto.fromJson(<String, dynamic>{
          'items': <dynamic>[transactionJson()],
          'has_more': true,
          'next_cursor': <String, dynamic>{
            'created_at': '2026-10-01T12:00:00.000Z',
            'id': 'tx-1',
          },
        }),
      );

      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor?['id'], 'tx-1');
      expect(page.isEmpty, isFalse);
    });

    test('maps an empty page with a null cursor', () {
      final EarningsTransactionPage page = EarningsMapper.pageToEntity(
        EarningsTransactionPageDto.fromJson(<String, dynamic>{}),
      );

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
      expect(page.isEmpty, isTrue);
    });
  });
}
