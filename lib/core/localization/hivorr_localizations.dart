import 'package:flutter/widgets.dart'
    show
        BuildContext,
        Localizations,
        LocalizationsDelegate,
        Locale;

import 'localization_exception.dart';
import 'localization_service.dart';
import 'supported_locales.dart';

/// Custom [LocalizationsDelegate] and translation accessor for Hivorr.
///
/// Registered in [MaterialApp.localizationsDelegates]. Flutter calls [load]
/// per locale and rebuilds the tree on locale change. [load] is fail-safe:
/// a missing/malformed file yields an empty table rather than crashing the
/// widget tree.
class HivorrLocalizations extends LocalizationsDelegate<HivorrLocalizations> {
  const HivorrLocalizations(
    [this._active = const <String, String>{},
    this._fallback = const <String, String>{},
    this._locale,
  ]);

  final Map<String, String> _active;
  final Map<String, String> _fallback;
  final Locale? _locale;

  final HivorrLocalizationService _service = const HivorrLocalizationService();

  /// Singleton delegate registered with [MaterialApp].
  static const HivorrLocalizations delegate = HivorrLocalizations();

  @override
  bool isSupported(Locale locale) => HivorrSupportedLocales.supported
      .any((Locale l) => l.languageCode == locale.languageCode);

  @override
  Future<HivorrLocalizations> load(Locale locale) async {
    late final Map<String, String> active;
    late final Map<String, String> fallback;
    try {
      active = await _service.loadTranslations(locale);
    } on LocalizationException {
      active = const <String, String>{};
    }
    try {
      fallback =
          await _service.loadTranslations(HivorrSupportedLocales.defaultLocale);
    } on LocalizationException {
      fallback = const <String, String>{};
    }
    return HivorrLocalizations(active, fallback, locale);
  }

  @override
  bool shouldReload(HivorrLocalizations old) => old._locale != _locale;

  /// Convenience accessor mirroring [Localizations.of].
  static HivorrLocalizations of(BuildContext context) {
    final HivorrLocalizations? result =
        Localizations.of<HivorrLocalizations>(context, HivorrLocalizations);
    return result ??
        (throw LocalizationException(
          'No HivorrLocalizations found in widget context',
        ));
  }

  /// Translates [key], applying [params] interpolation and the fallback chain
  /// (active locale → fallback locale → key name).
  String translate(String key, {Map<String, String>? params}) {
    final String resolved = _service.resolve(key, _active, _fallback);
    return _service.interpolate(resolved, params ?? const <String, String>{});
  }

  /// Resolves the plural form for [count] (CLDR-aware) and interpolates it.
  ///
  /// The `count` value is automatically exposed as the `{count}` parameter for
  /// templates such as `"{count} items"`.
  String plural(String key, int count, {Map<String, String>? params}) {
    final String resolved =
        _service.resolvePlural(key, count, _active, _fallback, locale: _locale);
    final Map<String, String> merged = <String, String>{
      'count': count.toString(),
      ...?params,
    };
    return _service.interpolate(resolved, merged);
  }
}
