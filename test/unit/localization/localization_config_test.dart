import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/localization_config.dart';

void main() {
  group('LocalizationConfig', () {
    test('constructs with all required fields', () {
      const LocalizationConfig config = LocalizationConfig(
        defaultLocale: Locale('en'),
        fallbackLocale: Locale('en'),
        supportedLocales: <Locale>[Locale('en')],
      );
      expect(config.defaultLocale.languageCode, 'en');
      expect(config.fallbackLocale.languageCode, 'en');
      expect(config.supportedLocales, hasLength(1));
    });

    test('default config has default+fallback inside supported list', () {
      expect(defaultLocalizationConfig.supportedLocales,
          contains(defaultLocalizationConfig.defaultLocale));
      expect(defaultLocalizationConfig.supportedLocales,
          contains(defaultLocalizationConfig.fallbackLocale));
    });
  });
}
