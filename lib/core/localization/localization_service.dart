import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import 'localization_exception.dart';

/// Low-level translation loader, resolver, interpolator, and pluralizer.
///
/// Stateless and side-effect free (beyond reading assets). All methods operate
/// on flat `Map<String, String>` translation tables, keeping key resolution at
/// O(1). Parameter interpolation is simple `{name}` substitution — no
/// expression evaluation, no code execution.
class HivorrLocalizationService {
  const HivorrLocalizationService();

  /// Loads and flattens `assets/translations/{languageCode}.json`.
  ///
  /// Throws [LocalizationException] when the asset is missing or malformed so
  /// callers (e.g. [HivorrLocalizations.load]) can fail safe to the default
  /// locale.
  Future<Map<String, String>> loadTranslations(Locale locale) async {
    final String path = 'assets/translations/${locale.languageCode}.json';
    try {
      final String raw = await rootBundle.loadString(path);
      return parseTranslationJson(raw, locale);
    } on LocalizationException {
      rethrow;
    } catch (e) {
      throw LocalizationException(
        'Failed to load translations for "${locale.languageCode}": $e',
        locale: locale,
      );
    }
  }

  /// Decodes a translation JSON string into a flat string map.
  ///
  /// Exposed for testing the malformed-JSON path without bundling a fixture
  /// asset. Throws [LocalizationException] when the content is not a JSON
  /// object or cannot be decoded.
  static Map<String, String> parseTranslationJson(String source, Locale locale) {
    try {
      final dynamic decoded = json.decode(source);
      if (decoded is! Map) {
        throw const FormatException('Translation root is not a JSON object');
      }
      final Map<String, dynamic> map = decoded as Map<String, dynamic>;
      return map.map(
        (dynamic k, dynamic v) => MapEntry<String, String>(
          k.toString(),
          v?.toString() ?? '',
        ),
      );
    } on LocalizationException {
      rethrow;
    } catch (e) {
      throw LocalizationException(
        'Malformed translation JSON for "${locale.languageCode}": $e',
        locale: locale,
      );
    }
  }

  /// Resolves [key] from [translations], then [fallback], else returns [key].
  String resolve(
    String key,
    Map<String, String> translations,
    Map<String, String>? fallback,
  ) =>
      lookup(key, translations, fallback) ?? key;

  /// Returns the resolved value or `null` when absent in both maps.
  ///
  /// Empty-string values are treated as missing so a blank translation never
  /// reaches the UI.
  String? lookup(
    String key,
    Map<String, String> translations,
    Map<String, String>? fallback,
  ) {
    final String? direct = translations[key];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    if (fallback != null) {
      final String? fb = fallback[key];
      if (fb != null && fb.isNotEmpty) {
        return fb;
      }
    }
    return null;
  }

  /// Replaces every `{name}` occurrence with `params[name]` (single pass).
  ///
  /// Unknown placeholders and extra params are left/ignored untouched — no
  /// recursion, so a param value containing `{`/`}` is never re-interpolated.
  String interpolate(String template, Map<String, String> params) {
    if (params.isEmpty) {
      return template;
    }
    String result = template;
    for (final MapEntry<String, String> entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// Selects the correct CLDR plural form for [count] and resolves it.
  ///
  /// The `zero` form is preferred when [count] is 0 and a `zero` key exists
  /// (English CLDR has no `zero` category, so this explicit step honors the
  /// `common.itemCount.zero` → "No items" expectation). Otherwise
  /// [Intl.pluralLogic] picks the form; missing specific forms fall back to
  /// `other`, then to the bare form key name.
  String resolvePlural(
    String key,
    int count,
    Map<String, String> translations,
    Map<String, String>? fallback, {
    Locale? locale,
  }) {
    final String? localeTag = locale?.languageCode;

    final String formKey;
    if (count == 0 &&
        (translations['$key.zero'] != null ||
            (fallback?['$key.zero'] != null))) {
      formKey = '$key.zero';
    } else {
      formKey = Intl.pluralLogic<String>(
        count,
        zero: '$key.zero',
        one: '$key.one',
        two: '$key.two',
        few: '$key.few',
        many: '$key.many',
        other: '$key.other',
        locale: localeTag,
      );
    }

    final String? direct = lookup(formKey, translations, fallback);
    if (direct != null) {
      return direct;
    }
    final String? other = lookup('$key.other', translations, fallback);
    if (other != null) {
      return other;
    }
    return formKey;
  }
}
