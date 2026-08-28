import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/database/storage_engine.dart';

import 'localization_config.dart';
import 'localization_exception.dart';
import 'supported_locales.dart';

/// App-wide locale state, propagated via [ChangeNotifier].
///
/// Restores a persisted locale on [initialize], validates every requested
/// locale against [LocalizationConfig.supportedLocales], and persists changes
/// to Hive through the injected [StorageEngine]. Persistence is best-effort:
/// a failed write never blocks the in-memory locale update.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({
    required this.config,
    required this.storage,
  });

  /// Locale allow-list and defaults sourced from [HivorrSupportedLocales].
  final LocalizationConfig config;

  /// Backing store for the persisted locale preference (Hive at runtime).
  final StorageEngine storage;

  static const String _box = 'locale_prefs';
  static const String _key = 'preferred_locale';

  Locale _currentLocale = HivorrSupportedLocales.defaultLocale;

  /// The active locale driving every translation lookup.
  Locale get currentLocale => _currentLocale;

  /// Locales the engine is willing to serve.
  List<Locale> get supportedLocales => config.supportedLocales;

  /// The fallback locale used when no preference is persisted.
  Locale get defaultLocale => config.defaultLocale;

  bool _isSupported(Locale locale) => config.supportedLocales
      .any((Locale l) => l.languageCode == locale.languageCode);

  Locale _deviceLocale() => PlatformDispatcher.instance.locale;

  /// Restores the persisted locale, falling back to the device locale or the
  /// default. [deviceLocale] overrides the device probe (test seam).
  Future<void> initialize({Locale? deviceLocale}) async {
    final Map<String, dynamic>? raw = await _readPreference();
    final String? code = raw == null ? null : raw['code'] as String?;
    if (code != null && code.isNotEmpty) {
      final Locale restored = Locale(code);
      if (_isSupported(restored)) {
        _currentLocale = restored;
        return;
      }
    }
    final Locale device = deviceLocale ?? _deviceLocale();
    _currentLocale = _isSupported(device) ? device : config.defaultLocale;
  }

  /// Updates [currentLocale], persists it, and notifies listeners.
  ///
  /// Throws [LocalizationException] for an unsupported locale; the current
  /// locale is left unchanged in that case.
  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale)) {
      throw LocalizationException(
        'Unsupported locale: ${locale.languageCode}',
        locale: locale,
      );
    }
    _currentLocale = locale;
    notifyListeners();
    try {
      await storage.put(
        _box,
        _key,
        <String, dynamic>{'code': locale.languageCode},
      );
    } catch (_) {
      // Best-effort persistence; in-memory locale already applied.
    }
  }

  /// Reverts to the device (or default) locale and clears the persisted choice.
  Future<void> resetToSystemLocale({Locale? deviceLocale}) async {
    final Locale device = deviceLocale ?? _deviceLocale();
    _currentLocale = _isSupported(device) ? device : config.defaultLocale;
    notifyListeners();
    try {
      await storage.delete(_box, _key);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<Map<String, dynamic>?> _readPreference() async {
    try {
      return await storage.get(_box, _key);
    } catch (_) {
      return null;
    }
  }
}
