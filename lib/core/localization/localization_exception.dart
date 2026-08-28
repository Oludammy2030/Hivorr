import 'dart:ui' show Locale;

/// Typed exception raised by the localization engine for structural failures.
///
/// Carries an optional [key] (the translation key that triggered the failure)
/// and [locale] (the locale being resolved) so logs and tests can attribute
/// the error precisely. The engine never logs translation *values* or
/// *parameters* — only structural errors surface here (missing file, malformed
/// JSON, unsupported locale).
class LocalizationException implements Exception {
  const LocalizationException(this.message, {this.key, this.locale});

  /// Human-readable description of the failure.
  final String message;

  /// The translation key involved, when applicable.
  final String? key;

  /// The locale involved, when applicable.
  final Locale? locale;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.write('LocalizationException: $message');
    if (key != null) {
      buffer.write(' (key: $key)');
    }
    if (locale != null) {
      buffer.write(' (locale: ${locale!.languageCode})');
    }
    return buffer.toString();
  }
}
