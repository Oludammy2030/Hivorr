import 'package:hivorr/shared/extensions/string_extensions.dart';

/// Reusable form-validation rules.
///
/// Every rule returns `null` when the value is valid and a user-facing error
/// message (in plain English — localization is added in EP-01-17) when invalid.
/// Rules operate only on raw [String?] values — no domain awareness.
class HivorrValidators {
  const HivorrValidators._();

  /// Required-field check. [field] is interpolated into the message.
  static String? required(String? value, {String? field}) {
    if (value == null || value.trim().isEmpty) {
      return field != null ? '$field is required' : 'This field is required';
    }
    return null;
  }

  /// Email format check.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a valid email address';
    }
    if (!value.trim().isValidEmail) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Phone format check (E.164 or local).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a valid phone number';
    }
    if (!value.trim().isValidPhone) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Minimum length check.
  static String? minLength(String? value, int min, {String? field}) {
    if (value == null || value.trim().length < min) {
      final String name = field ?? 'This field';
      return '$name must be at least $min characters';
    }
    return null;
  }

  /// Maximum length check.
  static String? maxLength(String? value, int max, {String? field}) {
    if (value != null && value.trim().length > max) {
      final String name = field ?? 'This field';
      return '$name must not exceed $max characters';
    }
    return null;
  }

  /// Password strength check: ≥ 8 chars with uppercase, lowercase, and digit.
  static String? passwordStrength(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password must be at least 8 characters with uppercase, '
          'lowercase, and number';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters with uppercase, '
          'lowercase, and number';
    }
    final bool hasUpper = value.contains(RegExp(r'[A-Z]'));
    final bool hasLower = value.contains(RegExp(r'[a-z]'));
    final bool hasDigit = value.contains(RegExp(r'[0-9]'));
    if (!hasUpper || !hasLower || !hasDigit) {
      return 'Password must be at least 8 characters with uppercase, '
          'lowercase, and number';
    }
    return null;
  }

  /// Numeric value check.
  static String? numeric(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a valid number';
    }
    if (num.tryParse(value.trim()) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  /// URL format check.
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a valid URL';
    }
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid URL';
    }
    return null;
  }

  /// Runs [validators] in order and returns the first non-null error, or
  /// `null` when every rule passes.
  static String? compose(
    String? value,
    List<String? Function(String?)> validators,
  ) {
    for (final String? Function(String?) validator in validators) {
      final String? result = validator(value ?? '');
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
