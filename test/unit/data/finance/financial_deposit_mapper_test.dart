import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/mappers/financial_deposit_mapper.dart';
import 'package:hivorr/data/models/deposit_dto.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

void main() {
  group('FinancialDepositMapper.toEntity', () {
    test('maps all fields and preserves the name-match status', () {
      final DepositDto dto = DepositDto(
        id: 'dep-1',
        currencyCode: 'NGN',
        amount: 150000,
        nameMatchStatus: 'matched',
        payerName: 'John Doe',
        nameMatchScore: 0.98,
        externalReference: 'TRF-123',
        status: 'credited',
        creditedAt: DateTime.utc(2026, 1, 2),
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final deposit = FinancialDepositMapper.toEntity(dto);

      expect(deposit.id, 'dep-1');
      expect(deposit.currencyCode, 'NGN');
      expect(deposit.amount, 150000);
      expect(deposit.nameMatchStatus, DepositNameMatchStatus.matched);
      expect(deposit.payerName, 'John Doe');
      expect(deposit.nameMatchScore, 0.98);
      expect(deposit.externalReference, 'TRF-123');
      expect(deposit.status, 'credited');
      expect(deposit.isCredited, isTrue);
      expect(deposit.creditedAt, DateTime.utc(2026, 1, 2));
      expect(deposit.createdAt, DateTime.utc(2026, 1, 1));
    });

    test('null optional fields map to null without throwing', () {
      final DepositDto dto = DepositDto(
        id: 'dep-2',
        currencyCode: 'USD',
        amount: 100,
        nameMatchStatus: 'pending',
      );

      final deposit = FinancialDepositMapper.toEntity(dto);

      expect(deposit.payerName, isNull);
      expect(deposit.nameMatchScore, isNull);
      expect(deposit.externalReference, isNull);
      expect(deposit.creditedAt, isNull);
      expect(deposit.status, 'pending');
      expect(deposit.isCredited, isFalse);
    });

    test('maps each persisted name-match value via the enum', () {
      for (final (String value, DepositNameMatchStatus expected) in <
          (String, DepositNameMatchStatus)>[
        ('unverified', DepositNameMatchStatus.unverified),
        ('pending', DepositNameMatchStatus.pending),
        ('matched', DepositNameMatchStatus.matched),
        ('mismatched', DepositNameMatchStatus.mismatched),
      ]) {
        final DepositDto dto = DepositDto(
          id: 'x',
          currencyCode: 'NGN',
          amount: 1,
          nameMatchStatus: value,
        );
        expect(
          FinancialDepositMapper.toEntity(dto).nameMatchStatus,
          expected,
        );
      }
    });

    test('unknown persisted status falls back to unverified', () {
      final DepositDto dto = DepositDto(
        id: 'x',
        currencyCode: 'NGN',
        amount: 1,
        nameMatchStatus: 'nope',
      );
      expect(
        FinancialDepositMapper.toEntity(dto).nameMatchStatus,
        DepositNameMatchStatus.unverified,
      );
    });
  });
}