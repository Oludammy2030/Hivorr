import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';

void main() {
  group('PayoutAccount.maskedAccountNumber', () {
    test('masks all but the last four digits with ***', () {
      const PayoutAccount account = PayoutAccount(
        id: 'acc-1',
        currencyCode: 'NGN',
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
        status: PayoutAccountStatus.pending,
      );
      expect(account.maskedAccountNumber, '***6789');
    });

    test('does not crash on a number of exactly four digits', () {
      const PayoutAccount account = PayoutAccount(
        id: 'acc-2',
        currencyCode: 'USD',
        bankName: 'Bank',
        accountNumber: '1234',
        accountName: 'Jane',
        status: PayoutAccountStatus.pending,
      );
      expect(account.maskedAccountNumber, '****');
    });

    test('does not crash on short or blank numbers', () {
      const PayoutAccount account = PayoutAccount(
        id: 'acc-3',
        currencyCode: 'GBP',
        bankName: 'Bank',
        accountNumber: '   ',
        accountName: 'Jane',
        status: PayoutAccountStatus.active,
        isVerified: true,
      );
      expect(account.maskedAccountNumber, '****');
    });
  });

  group('PayoutAccount.isUsable', () {
    test('is true only when verified AND active', () {
      PayoutAccount account = PayoutAccount(
        id: 'a',
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
        status: PayoutAccountStatus.active,
        isVerified: true,
      );
      expect(account.isUsable, isTrue);

      account = PayoutAccount(
        id: 'a',
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
        status: PayoutAccountStatus.pending,
        isVerified: true,
      );
      expect(account.isUsable, isFalse);

      account = PayoutAccount(
        id: 'a',
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
        status: PayoutAccountStatus.active,
        isVerified: false,
      );
      expect(account.isUsable, isFalse);

      account = PayoutAccount(
        id: 'a',
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
        status: PayoutAccountStatus.deactivated,
      );
      expect(account.isUsable, isFalse);
    });
  });
}