import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Localizations,
        Locale;

import 'hivorr_localizations.dart';

/// Ergonomic [BuildContext] accessors for translations.
///
/// `context.tr(TranslationKeys.commonOk)` resolves a key;
/// `context.plural(TranslationKeys.commonItemCount, count)` resolves a plural;
/// `context.l10n` returns the underlying [HivorrLocalizations];
/// `context.currentLocale` returns the active [Locale].
extension LocalizationExtension on BuildContext {
  /// The [HivorrLocalizations] instance for this context.
  HivorrLocalizations get l10n => HivorrLocalizations.of(this);

  /// Translates [key] with optional [params] interpolation.
  String tr(String key, {Map<String, String>? params}) =>
      HivorrLocalizations.of(this).translate(key, params: params);

  /// Resolves the plural form of [key] for [count].
  String plural(String key, int count, {Map<String, String>? params}) =>
      HivorrLocalizations.of(this).plural(key, count, params: params);

  /// The active locale for this context.
  Locale get currentLocale => Localizations.localeOf(this);
}
