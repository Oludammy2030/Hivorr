import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

void main() {
  group('HivorrValidators.required', () {
    test('returns error for null, empty and whitespace', () {
      expect(HivorrValidators.required(null), isNotNull);
      expect(HivorrValidators.required(''), isNotNull);
      expect(HivorrValidators.required('   '), isNotNull);
    });

    test('returns null for non-empty value', () {
      expect(HivorrValidators.required('x'), isNull);
    });

    test('interpolates field name', () {
      expect(
        HivorrValidators.required('', field: 'Email'),
        'Email is required',
      );
    });
  });

  group('HivorrValidators.email', () {
    test('accepts valid addresses', () {
      expect(HivorrValidators.email('a@b.co'), isNull);
      expect(HivorrValidators.email('first.last@mail.com'), isNull);
    });

    test('rejects invalid or empty', () {
      expect(HivorrValidators.email('nope'), isNotNull);
      expect(HivorrValidators.email('a@b'), isNotNull);
      expect(HivorrValidators.email(''), isNotNull);
    });
  });

  group('HivorrValidators.phone', () {
    test('accepts E.164 and local formats', () {
      expect(HivorrValidators.phone('+2348012345678'), isNull);
      expect(HivorrValidators.phone('08012345678'), isNull);
    });

    test('rejects too short or non-numeric', () {
      expect(HivorrValidators.phone('123'), isNotNull);
      expect(HivorrValidators.phone('abc'), isNotNull);
    });
  });

  group('HivorrValidators.length', () {
    test('minLength', () {
      expect(HivorrValidators.minLength('ab', 3), isNotNull);
      expect(HivorrValidators.minLength('abc', 3), isNull);
      expect(
        HivorrValidators.minLength('ab', 3, field: 'Code'),
        'Code must be at least 3 characters',
      );
    });

    test('maxLength', () {
      expect(HivorrValidators.maxLength('abcd', 3), isNotNull);
      expect(HivorrValidators.maxLength('abc', 3), isNull);
    });
  });

  group('HivorrValidators.passwordStrength', () {
    test('accepts strong password', () {
      expect(HivorrValidators.passwordStrength('Passw0rd'), isNull);
    });

    test('rejects weak passwords', () {
      expect(HivorrValidators.passwordStrength('short'), isNotNull);
      expect(HivorrValidators.passwordStrength('alllower1'), isNotNull);
      expect(HivorrValidators.passwordStrength('ALLUPPER1'), isNotNull);
      expect(HivorrValidators.passwordStrength('NoDigit'), isNotNull);
      expect(HivorrValidators.passwordStrength(''), isNotNull);
    });
  });

  group('HivorrValidators.numeric and url', () {
    test('numeric', () {
      expect(HivorrValidators.numeric('123'), isNull);
      expect(HivorrValidators.numeric('abc'), isNotNull);
      expect(HivorrValidators.numeric(''), isNotNull);
    });

    test('url', () {
      expect(HivorrValidators.url('https://example.com'), isNull);
      expect(HivorrValidators.url('not a url'), isNotNull);
      expect(HivorrValidators.url(''), isNotNull);
    });
  });

  group('HivorrValidators.compose', () {
    test('returns first failure', () {
      final String? result = HivorrValidators.compose('', <String? Function(String?)>[
        (String? v) => HivorrValidators.required(v),
        (String? v) => HivorrValidators.email(v),
      ]);
      expect(result, 'This field is required');
    });

    test('returns later failure when first passes', () {
      final String? result = HivorrValidators.compose('bob', <String? Function(String?)>[
        (String? v) => HivorrValidators.required(v),
        (String? v) => HivorrValidators.email(v),
      ]);
      expect(result, isNotNull);
    });

    test('returns null when all pass', () {
      final String? result = HivorrValidators.compose('a@b.co', <String? Function(String?)>[
        (String? v) => HivorrValidators.required(v),
        (String? v) => HivorrValidators.email(v),
      ]);
      expect(result, isNull);
    });
  });
}
