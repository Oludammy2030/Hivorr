import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

void main() {
  group('StringExtensions', () {
    test('capitalize', () {
      expect('hello'.capitalize, 'Hello');
      expect(''.capitalize, '');
    });

    test('truncate', () {
      expect('hello'.truncate(5), 'hello');
      expect('hello world'.truncate(5), 'hello…');
      expect('hi'.truncate(0), '');
    });

    test('initials', () {
      expect('John Doe'.initials, 'JD');
      expect('john'.initials, 'J');
      expect(''.initials, '');
      expect('   '.initials, '');
    });

    test('isValidEmail', () {
      expect('a@b.co'.isValidEmail, isTrue);
      expect('bob'.isValidEmail, isFalse);
      expect('a@b'.isValidEmail, isFalse);
    });

    test('isValidPhone', () {
      expect('+2348012345678'.isValidPhone, isTrue);
      expect('08012345678'.isValidPhone, isTrue);
      expect('abc'.isValidPhone, isFalse);
      expect('123'.isValidPhone, isFalse);
    });
  });

  group('NumericExtensions', () {
    test('toCurrency default Naira', () {
      expect(1500.toCurrency(), '₦1,500.00');
      expect(0.toCurrency(), '₦0.00');
    });

    test('toCurrency custom symbol', () {
      expect(10.toCurrency(symbol: '\$'), '\$10.00');
    });

    test('toOrdinal', () {
      expect(1.toOrdinal(), '1st');
      expect(2.toOrdinal(), '2nd');
      expect(3.toOrdinal(), '3rd');
      expect(4.toOrdinal(), '4th');
      expect(11.toOrdinal(), '11th');
      expect(21.toOrdinal(), '21st');
      expect(100.toOrdinal(), '100th');
      expect(0.toOrdinal(), '0th');
      expect((-1).toOrdinal(), '-1st');
    });
  });
}
