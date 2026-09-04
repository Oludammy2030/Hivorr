import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/models/supported_currency.dart';

void main() {
  group('SupportedCurrency', () {
    test('has exactly four currencies', () {
      expect(SupportedCurrency.values, hasLength(4));
    });

    test('registers codes NGN, GHS, USD, GBP', () {
      expect(SupportedCurrency.codes, containsAll(<String>['NGN', 'GHS', 'USD', 'GBP']));
    });

    test('maps display labels', () {
      expect(SupportedCurrency.ngn.name, 'Nigerian Naira');
      expect(SupportedCurrency.ghs.name, 'Ghanaian Cedi');
      expect(SupportedCurrency.usd.name, 'US Dollar');
      expect(SupportedCurrency.gbp.name, 'British Pound');
    });

    test('maps symbols', () {
      expect(SupportedCurrency.ngn.symbol, '\u20A6');
      expect(SupportedCurrency.ghs.symbol, '\u20B5');
      expect(SupportedCurrency.usd.symbol, '\$');
      expect(SupportedCurrency.gbp.symbol, '\u00A3');
    });

    test('fromCode resolves each currency', () {
      expect(SupportedCurrency.fromCode('NGN'), SupportedCurrency.ngn);
      expect(SupportedCurrency.fromCode('GHS'), SupportedCurrency.ghs);
      expect(SupportedCurrency.fromCode('USD'), SupportedCurrency.usd);
      expect(SupportedCurrency.fromCode('GBP'), SupportedCurrency.gbp);
    });

    test('fromCode returns null for unknown codes', () {
      expect(SupportedCurrency.fromCode('KES'), isNull);
      expect(SupportedCurrency.isSupported('KES'), isFalse);
    });

    test('isSupported true for registered codes', () {
      expect(SupportedCurrency.isSupported('NGN'), isTrue);
      expect(SupportedCurrency.isSupported('USD'), isTrue);
    });

    test('all register two decimal places', () {
      for (final currency in SupportedCurrency.values) {
        expect(currency.decimalPlaces, 2);
      }
    });
  });
}
