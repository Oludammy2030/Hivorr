/// A single PII detection/replacement rule.
///
/// [regex] is applied to the input text and every match is replaced with
/// [replacement] (EP-01-14 §5.5).
class PiiPattern {
  const PiiPattern({required this.regex, required this.replacement, this.name});

  /// Compiled pattern matched against log text.
  final RegExp regex;

  /// Replacement string emitted for every match.
  final String replacement;

  /// Optional identifier for diagnostics/tests.
  final String? name;
}

/// Stateless utility that strips or masks personally identifiable information
/// from log messages and structured context before any sink receives them.
///
/// This is defense-in-depth: callers should never pass PII to the logger, but
/// the redactor guarantees no email, phone, token, or account number reaches
/// a sink even if they do (EP-01-14 §5.5, §12).
class PiiRedactor {
  PiiRedactor({
    this.enabled = true,
    this.sensitiveKeyNames = defaultSensitiveKeyNames,
    List<PiiPattern>? patterns,
  }) : patterns = patterns ?? defaultPatterns;

  /// Whether redaction is active. When `false`, input passes through unchanged.
  final bool enabled;

  /// Ordered detection/replacement rules.
  final List<PiiPattern> patterns;

  /// Context keys whose values are always replaced with `'[REDACTED]'`.
  final Set<String> sensitiveKeyNames;

  /// Default detection rules (email, Nigerian phone, generic phone, bearer,
  /// JWT, 10-digit account number).
  static final List<PiiPattern> defaultPatterns = <PiiPattern>[
    PiiPattern(
      name: 'email',
      regex: RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      replacement: '***@***.***',
    ),
    PiiPattern(
      name: 'phoneNigerian',
      regex: RegExp(r'\+?234[\s-]?\d{3}[\s-]?\d{3}[\s-]?\d{4}'),
      replacement: '***-****-****',
    ),
    PiiPattern(
      name: 'phoneGeneric',
      regex: RegExp(r'\+?\d{10,15}'),
      replacement: '***',
    ),
    PiiPattern(
      name: 'bearer',
      regex: RegExp(r'Bearer\s+\S+'),
      replacement: 'Bearer ***',
    ),
    PiiPattern(
      name: 'jwt',
      regex: RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
      replacement: '***',
    ),
    PiiPattern(
      name: 'accountNumber',
      regex: RegExp(r'\b\d{10}\b'),
      replacement: '***',
    ),
  ];

  /// Default sensitive context key names (lowercased for matching).
  static const Set<String> defaultSensitiveKeyNames = <String>{
    'email',
    'password',
    'token',
    'secret',
    'apikey',
    'authorization',
    'cookie',
    'creditcard',
    'bankaccount',
    'pin',
    'otp',
    'ssn',
  };

  /// Redacts all known PII patterns from [text].
  String redact(String text) {
    if (!enabled || text.isEmpty) return text;
    var result = text;
    for (final pattern in patterns) {
      result = result.replaceAllMapped(
        pattern.regex,
        (_) => pattern.replacement,
      );
    }
    return result;
  }

  /// Redacts a context map: sensitive-key values become `'[REDACTED]'`, all
  /// other string values are pattern-redacted in place.
  Map<String, Object?> redactContext(Map<String, Object?> context) {
    if (!enabled) return Map<String, Object?>.from(context);
    final result = <String, Object?>{};
    for (final entry in context.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (sensitiveKeyNames.contains(lowerKey)) {
        result[entry.key] = '[REDACTED]';
      } else if (entry.value is String) {
        result[entry.key] = redact(entry.value as String);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Redacts email addresses only.
  String redactEmail(String text) => _redactNamed(<String>{'email'}, text);

  /// Redacts Nigerian and generic phone numbers.
  String redactPhone(String text) =>
      _redactNamed(<String>{'phoneNigerian', 'phoneGeneric'}, text);

  /// Redacts bearer tokens and JWTs.
  String redactToken(String text) =>
      _redactNamed(<String>{'bearer', 'jwt'}, text);

  /// Redacts 10-digit account numbers.
  String redactAccountNumber(String text) =>
      _redactNamed(<String>{'accountNumber'}, text);

  String _redactNamed(Set<String> names, String text) {
    if (!enabled || text.isEmpty) return text;
    var result = text;
    for (final pattern in patterns) {
      if (names.contains(pattern.name)) {
        result = result.replaceAllMapped(
          pattern.regex,
          (_) => pattern.replacement,
        );
      }
    }
    return result;
  }
}
