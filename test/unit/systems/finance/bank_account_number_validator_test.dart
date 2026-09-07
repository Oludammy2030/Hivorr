import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/helpers/bank_account_number_validator.dart';

void main() {
  group('BankAccountNumberValidator.validate', () {
    test('accepts a 10-digit NUBAN for NGN', () {
      expect(
        BankAccountNumberValidator.validate(
          value: '0123456789',
          currencyCode: 'NGN',
        ),
        isNull,
      );
    });

    test('rejects 9 and 11 digit NUBANs for NGN', () {
      expect(
        BankAccountNumberValidator.validate(
          value: '012345678',
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
      expect(
        BankAccountNumberValidator.validate(
          value: '00123456789',
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
    });

    test('rejects non-numeric input', () {
      expect(
        BankAccountNumberValidator.validate(
          value: 'abcdefghij',
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
      expect(
        BankAccountNumberValidator.validate(
          value: '012345678A',
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
    });

    test('rejects blank input', () {
      expect(
        BankAccountNumberValidator.validate(
          value: '   ',
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
      expect(
        BankAccountNumberValidator.validate(
          value: '',
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
      expect(
        BankAccountNumberValidator.validate(
          value: null,
          currencyCode: 'NGN',
        ),
        isNotNull,
      );
    });

    test('accepts 8-15 digit account numbers for non-NGN currencies', () {
      for (final String code in <String>['GHS', 'USD', 'GBP']) {
        expect(
          BankAccountNumberValidator.validate(
            value: '12345678',
            currencyCode: code,
          ),
          isNull,
          reason: '$code 8 digits',
        );
        expect(
          BankAccountNumberValidator.validate(
            value: '123456789012345',
            currencyCode: code,
          ),
          isNull,
          reason: '$code 15 digits',
        );
      }
    });

    test('rejects account numbers outside 8-15 digits for non-NGN currencies',
        () {
      expect(
        BankAccountNumberValidator.validate(
          value: '1234567',
          currencyCode: 'USD',
        ),
        isNotNull,
      );
      expect(
        BankAccountNumberValidator.validate(
          value: '1234567890123456',
          currencyCode: 'USD',
        ),
        isNotNull,
      );
    });

    test('isValid mirrors validate', () {
      expect(
        BankAccountNumberValidator.isValid(
          value: '0123456789',
          currencyCode: 'NGN',
        ),
        isTrue,
      );
      expect(
        BankAccountNumberValidator.isValid(
          value: '012345678',
          currencyCode: 'NGN',
        ),
        isFalse,
      );
    });
  });
}