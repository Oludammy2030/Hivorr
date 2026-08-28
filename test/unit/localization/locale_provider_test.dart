import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/locale_provider.dart';
import 'package:hivorr/core/localization/localization_config.dart';
import 'package:hivorr/core/localization/localization_exception.dart';
import 'package:hivorr/core/localization/supported_locales.dart';

import '../../test_helpers.dart';

void main() {
  late FakeStorageEngine storage;

  setUp(() {
    storage = FakeStorageEngine();
  });

  LocaleProvider build({LocalizationConfig? config}) => LocaleProvider(
        config: config ?? defaultLocalizationConfig,
        storage: storage,
      );

  group('LocaleProvider.initialize', () {
    test('falls back to default locale when nothing is persisted', () async {
      final LocaleProvider provider = build();
      await provider.initialize();
      expect(provider.currentLocale.languageCode,
          HivorrSupportedLocales.defaultLocale.languageCode);
    });

    test('falls back to device locale when nothing is persisted', () async {
      final LocaleProvider provider = build();
      await provider.initialize(deviceLocale: const Locale('en'));
      expect(provider.currentLocale.languageCode, 'en');
    });

    test('restores a previously persisted, supported locale', () async {
      final LocaleProvider writer = build();
      await writer.setLocale(const Locale('en'));

      final LocaleProvider reader = build();
      await reader.initialize();
      expect(reader.currentLocale.languageCode, 'en');
    });

    test('falls back to default when persisted locale is unsupported',
        () async {
      // Persist an unsupported code, then read with the default config.
      await storage.put('locale_prefs', 'preferred_locale',
          <String, dynamic>{'code': 'xx'});
      final LocaleProvider reader = build();
      await reader.initialize();
      expect(reader.currentLocale.languageCode,
          HivorrSupportedLocales.defaultLocale.languageCode);
    });
  });

  group('LocaleProvider.setLocale', () {
    test('updates currentLocale and notifies listeners once', () async {
      final LocaleProvider provider = build();
      await provider.initialize();
      int notifications = 0;
      provider.addListener(() => notifications++);
      await provider.setLocale(const Locale('en'));
      expect(provider.currentLocale.languageCode, 'en');
      expect(notifications, 1);
    });

    test('persists the new locale', () async {
      final LocaleProvider provider = build();
      await provider.initialize();
      await provider.setLocale(const Locale('en'));
      final Map<String, dynamic>? stored =
          await storage.get('locale_prefs', 'preferred_locale');
      expect(stored?['code'], 'en');
    });

    test('throws LocalizationException for an unsupported locale', () async {
      final LocaleProvider provider = build();
      await provider.initialize();
      expect(
        () => provider.setLocale(const Locale('xx')),
        throwsA(isA<LocalizationException>()),
      );
      expect(provider.currentLocale.languageCode,
          HivorrSupportedLocales.defaultLocale.languageCode);
    });
  });

  group('LocaleProvider.resetToSystemLocale', () {
    test('clears persisted preference and uses device locale', () async {
      final LocaleProvider provider = build();
      await provider.initialize();
      await provider.setLocale(const Locale('en'));
      await provider.resetToSystemLocale(deviceLocale: const Locale('en'));
      expect(provider.currentLocale.languageCode, 'en');
      final Map<String, dynamic>? stored =
          await storage.get('locale_prefs', 'preferred_locale');
      expect(stored, isNull);
    });
  });
}
