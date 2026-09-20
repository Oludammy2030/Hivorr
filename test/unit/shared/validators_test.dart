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
      expect(HivorrValidators.passwordStrength('Passw0rd!'), isNull);
    });

    test('rejects weak passwords', () {
      expect(HivorrValidators.passwordStrength('short'), isNotNull);
      expect(HivorrValidators.passwordStrength('alllower1!'), isNotNull);
      expect(HivorrValidators.passwordStrength('ALLUPPER1!'), isNotNull);
      expect(HivorrValidators.passwordStrength('NoDigit!'), isNotNull);
      expect(HivorrValidators.passwordStrength('NoSymbol1'), isNotNull);
      expect(HivorrValidators.passwordStrength(''), isNotNull);
    });
  });

  group('PasswordPolicy', () {
    test('supabase policy requires 8 chars, upper, lower, digit, symbol', () {
      const PasswordPolicy policy = PasswordPolicy.supabase;

      // too short
      PasswordPolicyResult result = policy.evaluate('Ab1!');
      expect(result.isValid, isFalse);
      expect(result.meetsMinimumLength, isFalse);
      expect(result.strength, PasswordStrength.medium);

      // all classes met, meets length
      result = policy.evaluate('Abc123!9');
      expect(result.isValid, isTrue);
      expect(result.strength, PasswordStrength.strong);
    });

    test('maps each character class correctly', () {
      const PasswordPolicy policy = PasswordPolicy.supabase;
      final PasswordPolicyResult result = policy.evaluate('hello');

      expect(result.satisfied[PasswordCharacterClass.lowercase], isTrue);
      expect(result.satisfied[PasswordCharacterClass.uppercase], isFalse);
      expect(result.satisfied[PasswordCharacterClass.number], isFalse);
      expect(result.satisfied[PasswordCharacterClass.symbol], isFalse);
      expect(result.satisfiedCount, 1);
    });

    test('strength classification', () {
      const PasswordPolicy policy = PasswordPolicy.supabase;

      // 0-1 classes → weak
      expect(policy.evaluate('hello').strength, PasswordStrength.weak);

      // 2-3 classes → medium
      expect(policy.evaluate('Hello').strength, PasswordStrength.medium);
      expect(policy.evaluate('Hello123').strength, PasswordStrength.medium);
      expect(policy.evaluate('Hello1!').strength, PasswordStrength.medium);

      // 4 classes but below min length → medium
      expect(policy.evaluate('H1!x').strength, PasswordStrength.medium);

      // all classes + meets min length → strong
      expect(policy.evaluate('Hello123!').strength, PasswordStrength.strong);
      expect(policy.evaluate('Str0ng!Pw').strength, PasswordStrength.strong);
    });

    test('symbol set matches Supabase allowed symbols', () {
      const PasswordPolicy policy = PasswordPolicy.supabase;

      // symbols from the documented Supabase allowed set
      expect(
        policy.evaluate('Aa1!').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1@').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1#').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1_').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1-').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1`').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1~').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );
      expect(
        policy.evaluate('Aa1[').satisfied[PasswordCharacterClass.symbol],
        isTrue,
      );

      // non-symbol
      expect(
        policy.evaluate('Abcdefg1').satisfied[PasswordCharacterClass.symbol],
        isFalse,
      );
    });

    test('invalidMessage reflects the policy', () {
      expect(
        PasswordPolicy.supabase.invalidMessage,
        contains('at least 8 characters'),
      );
      expect(
        PasswordPolicy.supabase.invalidMessage,
        contains('lowercase letter'),
      );
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
      final String? result =
          HivorrValidators.compose('', <String? Function(String?)>[
            (String? v) => HivorrValidators.required(v),
            (String? v) => HivorrValidators.email(v),
          ]);
      expect(result, 'This field is required');
    });

    test('returns later failure when first passes', () {
      final String? result =
          HivorrValidators.compose('bob', <String? Function(String?)>[
            (String? v) => HivorrValidators.required(v),
            (String? v) => HivorrValidators.email(v),
          ]);
      expect(result, isNotNull);
    });

    test('returns null when all pass', () {
      final String? result =
          HivorrValidators.compose('a@b.co', <String? Function(String?)>[
            (String? v) => HivorrValidators.required(v),
            (String? v) => HivorrValidators.email(v),
          ]);
      expect(result, isNull);
    });
  });
}
