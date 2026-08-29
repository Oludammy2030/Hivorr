// Public API barrel for the Hivorr localization & internationalization engine.
//
// Importing this single file exposes every localization primitive so
// downstream code (EP-02+ screens, EP-01-19/20 test infrastructure) depends
// on one stable surface:
//
// ```dart
// import 'package:hivorr/core/localization/localization.dart';
// ```
export 'hivorr_localizations.dart';
export 'locale_provider.dart';
export 'localization_config.dart';
export 'localization_exception.dart';
export 'localization_extension.dart';
export 'localization_service.dart';
export 'supported_locales.dart';
export 'translation_keys.dart';
