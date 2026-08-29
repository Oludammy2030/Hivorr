import 'package:flutter/widgets.dart' show Locale;

import 'supported_locales.dart';

/// Immutable configuration for the localization engine.
///
/// Centralizes the default locale, the fallback locale (used when a key is
/// missing in the active locale), and the full list of supported locales. The
/// [defaultLocalizationConfig] singleton mirrors [HivorrSupportedLocales] so
/// consumers can wire the engine without reconstructing the registry.
class LocalizationConfig {
  const LocalizationConfig({
    required this.defaultLocale,
    required this.fallbackLocale,
    required this.supportedLocales,
  });

  /// The locale used when no preference is persisted and the device locale is
  /// unsupported.
  final Locale defaultLocale;

  /// The locale whose translations backfill any missing key in the active
  /// locale (always [HivorrSupportedLocales.defaultLocale] for now).
  final Locale fallbackLocale;

  /// Every locale the engine is willing to serve.
  final List<Locale> supportedLocales;
}

/// Default engine configuration, derived from [HivorrSupportedLocales].
const LocalizationConfig defaultLocalizationConfig = LocalizationConfig(
  defaultLocale: HivorrSupportedLocales.defaultLocale,
  fallbackLocale: HivorrSupportedLocales.defaultLocale,
  supportedLocales: HivorrSupportedLocales.supported,
);
