import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

void main() {
  group('BalanceFormatter.formatBalance', () {
    test('formats NGN with naira symbol and thousands separator', () {
      expect(BalanceFormatter.formatBalance(50000, 'NGN'), '\u20A650,000.00');
    });

    test('formats GHS with cedi symbol', () {
      expect(BalanceFormatter.formatBalance(1200, 'GHS'), '\u20B51,200.00');
    });

    test('formats USD with dollar symbol', () {
      expect(BalanceFormatter.formatBalance(100, 'USD'), '\$100.00');
    });

    test('formats GBP with pound symbol and two decimals', () {
      expect(BalanceFormatter.formatBalance(75.5, 'GBP'), '\u00A375.50');
    });

    test('formats zero as 0.00', () {
      expect(BalanceFormatter.formatBalance(0, 'NGN'), '\u20A60.00');
    });

    test('throws ArgumentError for negative amounts', () {
      expect(
        () => BalanceFormatter.formatBalance(-1, 'NGN'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('falls back to code-only for unsupported currencies', () {
      expect(BalanceFormatter.formatBalance(100, 'XYZ'), '100.0 XYZ');
    });

    test('formats whole number with two decimals', () {
      expect(BalanceFormatter.formatBalance(1000, 'USD'), '\$1,000.00');
    });
  });
}
