import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/mappers/financial_mapper.dart';
import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';

import '../../../support/fakes/finance/fake_financial_remote_data_source.dart';

void main() {
  group('FinancialMapper.profileToEntity', () {
    test('maps all profile fields', () {
      final FinancialProfile profile = FinancialMapper.profileToEntity(
        seedProfileDto(
          id: 'p1',
          status: 'suspended',
          defaultCurrency: 'GBP',
        ),
      );
      expect(profile.id, 'p1');
      expect(profile.entityId, 'u1');
      expect(profile.status, 'suspended');
      expect(profile.defaultCurrency, 'GBP');
      expect(profile.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(profile.isActive, isFalse);
    });

    test('isActive is true for active profile', () {
      final FinancialProfile profile = FinancialMapper.profileToEntity(
        seedProfileDto(),
      );
      expect(profile.status, 'active');
      expect(profile.isActive, isTrue);
    });
  });

  group('FinancialMapper.accountToEntity', () {
    test('maps account fields including activation details', () {
      final CurrencyAccount account = FinancialMapper.accountToEntity(
        seedAccountDto(
          id: 'acc-9',
          currencyCode: 'USD',
          accountStatus: 'active',
          receivingBankName: 'Bank of America',
          receivingAccountNumber: '1234567890',
        ),
      );
      expect(account.id, 'acc-9');
      expect(account.financialProfileId, 'profile-1');
      expect(account.entityId, 'u1');
      expect(account.currencyCode, 'USD');
      expect(account.accountStatus, 'active');
      expect(account.receivingBankName, 'Bank of America');
      expect(account.receivingAccountNumber, '1234567890');
      expect(account.isActive, isTrue);
      expect(account.isPending, isFalse);
    });

    test('pending account derives isPending', () {
      final CurrencyAccount account = FinancialMapper.accountToEntity(
        seedAccountDto(accountStatus: 'pending', receivingBankName: null),
      );
      expect(account.isPending, isTrue);
      expect(account.isActive, isFalse);
      expect(account.receivingBankName, isNull);
    });
  });

  group('FinancialMapper.balanceToEntity', () {
    test('maps all balance fields', () {
      final Balance balance = FinancialMapper.balanceToEntity(
        seedBalanceDto(
          currencyCode: 'NGN',
          available: 50000,
          held: 1000,
          pending: 200,
          totalDeposited: 51200,
          totalWithdrawn: 0,
        ),
      );
      expect(balance.currencyCode, 'NGN');
      expect(balance.availableBalance, 50000);
      expect(balance.heldBalance, 1000);
      expect(balance.pendingBalance, 200);
      expect(balance.totalDeposited, 51200);
      expect(balance.totalWithdrawn, 0);
      expect(balance.totalBalance, 51200);
      expect(balance.hasBalance, isTrue);
    });

    test('zero balance has hasBalance false and zero total', () {
      final Balance balance = FinancialMapper.balanceToEntity(
        seedBalanceDto(available: 0, held: 0, pending: 0),
      );
      expect(balance.hasBalance, isFalse);
      expect(balance.totalBalance, 0);
    });
  });

  group('FinancialMapper.statusToEntity', () {
    test('maps full aggregate with balances, escrow, and limit', () {
      final FinancialStatus status = FinancialMapper.statusToEntity(
        seedStatusDto(
          defaultCurrency: 'NGN',
          profileStatus: 'active',
          balances: <BalanceDto>[
            seedBalanceDto(
              currencyCode: 'NGN',
              available: 100,
              held: 0,
              pending: 0,
            ),
            seedBalanceDto(
              currencyCode: 'USD',
              available: 50,
              held: 0,
              pending: 0,
            ),
          ],
          activeEscrowCount: 2,
          cashoutLimit: 250000,
        ),
      );
      expect(status.defaultCurrency, 'NGN');
      expect(status.profileStatus, 'active');
      expect(status.balances, hasLength(2));
      expect(status.balances.first.currencyCode, 'NGN');
      expect(status.activeEscrowCount, 2);
      expect(status.cashoutLimit, 250000);
      expect(status.isActive, isTrue);
    });
  });

  group('FinancialProfileDto.fromJson', () {
    test('parses snake_case JSON with accounts array', () {
      final FinancialProfileDto dto = FinancialProfileDto.fromJson(
        <String, dynamic>{
          'id': 'p1',
          'entity_id': 'u1',
          'status': 'active',
          'default_currency': 'GHS',
          'created_at': '2026-01-01T00:00:00.000Z',
          'currency_accounts': <dynamic>[
            <String, dynamic>{
              'id': 'a1',
              'financial_profile_id': 'p1',
              'entity_id': 'u1',
              'currency_code': 'GHS',
              'account_status': 'pending',
              'receiving_account_number': null,
              'receiving_bank_name': null,
              'activated_at': null,
            },
          ],
        },
      );
      expect(dto.id, 'p1');
      expect(dto.defaultCurrency, 'GHS');
      expect(dto.currencyAccounts, hasLength(1));
      expect(dto.currencyAccounts.single.accountStatus, 'pending');
    });

    test('missing fields fall back to defaults', () {
      final FinancialProfileDto dto = FinancialProfileDto.fromJson(
        <String, dynamic>{},
      );
      expect(dto.id, '');
      expect(dto.status, 'active');
      expect(dto.defaultCurrency, 'NGN');
      expect(dto.currencyAccounts, isEmpty);
    });
  });

  group('BalanceDto.fromJson', () {
    test('parses and defaults numeric types', () {
      final BalanceDto dto = BalanceDto.fromJson(
        <String, dynamic>{
          'currency_code': 'NGN',
          'available_balance': '50000',
          'held_balance': 1000,
          'pending_balance': null,
        },
      );
      expect(dto.currencyCode, 'NGN');
      expect(dto.availableBalance, 50000);
      expect(dto.heldBalance, 1000);
      expect(dto.pendingBalance, 0);
    });
  });

  group('FinancialStatusDto.fromJson', () {
    test('parses full aggregate JSON', () {
      final FinancialStatusDto dto = FinancialStatusDto.fromJson(
        <String, dynamic>{
          'default_currency': 'NGN',
          'profile_status': 'active',
          'balances': <dynamic>[
            <String, dynamic>{
              'currency_code': 'NGN',
              'available_balance': 100,
              'held_balance': 0,
              'pending_balance': 0,
            },
          ],
          'active_escrow_count': 3,
          'cashout_limit': 500000,
        },
      );
      expect(dto.defaultCurrency, 'NGN');
      expect(dto.balances, hasLength(1));
      expect(dto.activeEscrowCount, 3);
      expect(dto.cashoutLimit, 500000);
    });
  });
}
