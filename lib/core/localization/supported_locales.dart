import 'package:flutter/widgets.dart' show Locale;

/// Registry of locales the Hivorr app can serve, plus the resolution callback
/// consumed by [MaterialApp.localeResolutionCallback].
///
/// EP-02+ extends [supported] (and the corresponding `assets/translations/`
/// JSON files) — the engine itself requires no changes to add a language.
class HivorrSupportedLocales {
  HivorrSupportedLocales._();

  /// The locale used when no preference or device match is available.
  static const Locale defaultLocale = Locale('en');

  /// Locales the engine can serve. EP-02+ appends to this list.
  static const List<Locale> supported = <Locale>[Locale('en')];

  /// Resolves a device [locale] against [supportedLocales].
  ///
  /// Returns the matching supported locale when the device language code is
  /// present in [supportedLocales]; otherwise falls back to [defaultLocale].
  /// A `null` device locale also resolves to [defaultLocale].
  static Locale resolve(Locale? locale, Iterable<Locale> supportedLocales) {
    if (locale == null) {
      return defaultLocale;
    }
    for (final Locale candidate in supportedLocales) {
      if (candidate.languageCode == locale.languageCode) {
        return candidate;
      }
    }
    return defaultLocale;
  }
}
