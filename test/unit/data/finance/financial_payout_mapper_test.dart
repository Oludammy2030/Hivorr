import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/mappers/financial_payout_mapper.dart';
import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';

void main() {
  group('FinancialPayoutMapper.boundAccountFromBind', () {
    test('builds a pending account from the bind RPC result plus form values',
        () {
      const PayoutBindDto bind = PayoutBindDto(
        payoutAccountId: 'acc-1',
        currencyCode: 'ngn',
        status: 'pending',
      );

      final account = FinancialPayoutMapper.boundAccountFromBind(
        bind: bind,
        bankName: '  Guaranty Trust  ',
        accountNumber: ' 0123456789 ',
        accountName: '  John Doe ',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(account.id, 'acc-1');
      expect(account.currencyCode, 'ngn');
      expect(account.bankName, 'Guaranty Trust');
      expect(account.accountNumber, '0123456789');
      expect(account.accountName, 'John Doe');
      expect(account.status, PayoutAccountStatus.pending);
      expect(account.isVerified, isFalse);
      expect(account.createdAt, DateTime.utc(2026, 1, 1));
    });

    test('maps active status from persisted string', () {
      const PayoutBindDto bind = PayoutBindDto(
        payoutAccountId: 'acc-1',
        currencyCode: 'NGN',
        status: 'active',
      );

      final account = FinancialPayoutMapper.boundAccountFromBind(
        bind: bind,
        bankName: 'Bank',
        accountNumber: '0123456789',
        accountName: 'Name',
      );

      expect(account.status, PayoutAccountStatus.active);
    });

    test('masks the stored account number for display', () {
      const PayoutBindDto bind = PayoutBindDto(
        payoutAccountId: 'acc-1',
        currencyCode: 'NGN',
        status: 'pending',
      );

      final account = FinancialPayoutMapper.boundAccountFromBind(
        bind: bind,
        bankName: 'Bank',
        accountNumber: '0123456789',
        accountName: 'Name',
      );

      expect(account.maskedAccountNumber, '***6789');
    });
  });

  group('FinancialPayoutMapper.withdrawalToEntity', () {
    test('maps the withdraw RPC data object onto the entity', () {
      const WithdrawalDto dto = WithdrawalDto(
        payoutId: 'pay-1',
        amount: 50000,
        fee: 0,
        netAmount: 50000,
        cashoutRemaining: 450000,
      );

      final WithdrawalResult result =
          FinancialPayoutMapper.withdrawalToEntity(dto);

      expect(result.payoutId, 'pay-1');
      expect(result.amount, 50000);
      expect(result.fee, 0);
      expect(result.netAmount, 50000);
      expect(result.cashoutRemaining, 450000);
    });
  });
}