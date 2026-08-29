import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/supported_locales.dart';

void main() {
  group('HivorrSupportedLocales', () {
    test('default locale is en', () {
      expect(HivorrSupportedLocales.defaultLocale.languageCode, 'en');
    });

    test('supported contains at least en', () {
      expect(HivorrSupportedLocales.supported, isNotEmpty);
      expect(
        HivorrSupportedLocales.supported
            .any((l) => l.languageCode == 'en'),
        isTrue,
      );
    });

    test('resolve returns the matching supported locale', () {
      const Locale device = Locale('en');
      final Locale resolved = HivorrSupportedLocales.resolve(
        device,
        HivorrSupportedLocales.supported,
      );
      expect(resolved.languageCode, 'en');
    });

    test('resolve returns default for an unsupported device locale', () {
      const Locale device = Locale('fr');
      final Locale resolved = HivorrSupportedLocales.resolve(
        device,
        HivorrSupportedLocales.supported,
      );
      expect(resolved.languageCode, 'en');
    });

    test('resolve returns default when device locale is null', () {
      final Locale resolved = HivorrSupportedLocales.resolve(
        null,
        HivorrSupportedLocales.supported,
      );
      expect(resolved.languageCode, 'en');
    });
  });
}
