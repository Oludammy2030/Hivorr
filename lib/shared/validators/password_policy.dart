import 'package:flutter/foundation.dart';

/// The character classes a password may be required to contain.
///
/// The [pattern] for each class deliberately mirrors the exact semantics of
/// Supabase Auth's password-requirement presets:
///   * lowercase, uppercase, digit (0-9) — plain Unicode-ASCII classes;
///   * symbol — the documented Supabase allowed-symbol set
///     ``!@#$%^&*()_+-=[]{};':"|<>?,./`~``.
///
/// Keeping the symbol set identical to the server's means the client never
/// claims a password satisfies the requirement Supabase would reject (and
/// never imposes a stricter set the server would not enforce).
enum PasswordCharacterClass {
  lowercase('Lowercase letter', '[a-z]'),
  uppercase('Uppercase letter', '[A-Z]'),
  number('Number', '[0-9]'),
  symbol('Symbol', r'''[!@#$%^&*()_+\-=\[\]{};':"|<>?,./`~]''');

  const PasswordCharacterClass(this.label, this.pattern);

  /// Display label shown in the requirements checklist.
  final String label;

  /// Regex pattern matching at least one character of this class.
  final String pattern;

  /// Returns true when [value] contains at least one character of this class.
  bool matches(String value) => RegExp(pattern).hasMatch(value);
}

/// Classifies how far a password is from the configured requirements.
///
/// Weak → red, Medium → amber, Strong → green on the strength indicator.
/// The classification is derived from password *characteristics* against the
/// configured [PasswordPolicy] — not from length alone.
enum PasswordStrength {
  weak('Weak'),
  medium('Medium'),
  strong('Strong');

  const PasswordStrength(this.label);

  /// Display label shown with the strength indicator.
  final String label;
}

/// Result of evaluating a password against a [PasswordPolicy].
@immutable
class PasswordPolicyResult {
  const PasswordPolicyResult({
    required this.satisfied,
    required this.meetsMinimumLength,
  });

  /// Per-character-class satisfaction (keys cover every required class).
  final Map<PasswordCharacterClass, bool> satisfied;

  /// Whether the password meets the configured minimum length.
  final bool meetsMinimumLength;

  /// Every required character class is present.
  bool get meetsAllCharacterRequirements =>
      satisfied.values.every((bool met) => met);

  /// The password satisfies the full policy (all classes + minimum length).
  bool get isValid => meetsAllCharacterRequirements && meetsMinimumLength;

  /// Number of required character classes present.
  int get satisfiedCount {
    int count = 0;
    for (final bool met in satisfied.values) {
      if (met) {
        count++;
      }
    }
    return count;
  }

  /// Three-band strength derived from characteristics + configured policy:
  ///
  ///  * weak — 0-1 character classes met (or empty);
  ///  * medium — 2-3 classes met, OR all classes met but below minimum length;
  ///  * strong — all classes met AND at or above minimum length.
  PasswordStrength get strength {
    if (satisfiedCount <= 1) {
      return PasswordStrength.weak;
    }
    if (!meetsAllCharacterRequirements || !meetsMinimumLength) {
      return PasswordStrength.medium;
    }
    return PasswordStrength.strong;
  }
}

/// The password requirements the frontend communicates to the user.
///
/// This is a *mirror* of the Supabase Auth policy — a single source of truth
/// for the checklist, the strength indicator, and form validity. Supabase
/// remains the authoritative enforcement layer; this policy is guidance only
/// and must never be more permissive than the server.
class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 8,
    this.required = const <PasswordCharacterClass>[
      PasswordCharacterClass.lowercase,
      PasswordCharacterClass.uppercase,
      PasswordCharacterClass.number,
      PasswordCharacterClass.symbol,
    ],
  });

  /// Minimum password length.
  final int minLength;

  /// Character classes that must each appear at least once.
  final List<PasswordCharacterClass> required;

  /// The Supabase policy this app mirrors: minimum 8 characters and the
  /// strongest preset (`lower_upper_letters_digits_symbols`).
  ///
  /// Kept in sync with `supabase/config.toml` →
  /// `[auth] minimum_password_length = 8` and
  /// `password_requirements = "lower_upper_letters_digits_symbols"`.
  static const PasswordPolicy supabase = PasswordPolicy(minLength: 8);

  /// Evaluates [value] against the policy without retaining or exposing it.
  PasswordPolicyResult evaluate(String? value) {
    final String password = value ?? '';
    return PasswordPolicyResult(
      satisfied: <PasswordCharacterClass, bool>{
        for (final PasswordCharacterClass cls in required)
          cls: cls.matches(password),
      },
      meetsMinimumLength: password.length >= minLength,
    );
  }

  /// Neutral user-facing message describing a rejected password.
  String get invalidMessage {
    final String classes = required
        .map((PasswordCharacterClass cls) => cls.label.toLowerCase())
        .join(', ');
    return 'Password must be at least $minLength characters with at least '
        'one of each: $classes.';
  }
}
