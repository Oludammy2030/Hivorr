import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/hivorr_localizations.dart';
import 'package:hivorr/core/localization/locale_provider.dart';
import 'package:hivorr/core/localization/localization_config.dart';
import 'package:hivorr/core/localization/localization_extension.dart';
import 'package:hivorr/core/localization/localization_service.dart';
import 'package:hivorr/core/localization/translation_keys.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../support/harnesses/widget_harness.dart';
import '../test_helpers.dart'
    show FakeLocalizationsDelegate, FakeStorageEngine;

/// Integration config that mirrors the EP-01-17 engine but extends the
/// supported set with `fr` so the language-switching scenario can exercise a
/// second real locale through [FakeLocalizationsDelegate] (which constructs
/// genuine [HivorrLocalizations] instances from in-memory maps).
const LocalizationConfig integrationConfig = LocalizationConfig(
  defaultLocale: Locale('en'),
  fallbackLocale: Locale('en'),
  supportedLocales: <Locale>[Locale('en'), Locale('fr')],
);

/// Builds a localized [MaterialApp] driven by the injected [LocaleProvider].
///
/// The [Consumer] rebuilds the inner [MaterialApp] (and therefore re-runs the
/// [FakeLocalizationsDelegate]) whenever the provider emits a new locale,
/// proving the locale provider propagates to the widget tree.
Widget _localizedApp(LocaleProvider provider, Widget home) =>
    Consumer<LocaleProvider>(
      builder: (BuildContext context, LocaleProvider p, _) => MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          FakeLocalizationsDelegate(),
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: integrationConfig.supportedLocales,
        locale: p.currentLocale,
        home: home,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final HivorrLocalizationService service = const HivorrLocalizationService();

  group('Localization integration — translation loading', () {
    test('loads en.json from assets and translates a real key', () async {
      final Map<String, String> en =
          await service.loadTranslations(const Locale('en'));
      expect(en, isNotEmpty);
      expect(en['common.ok'], 'OK');

      final HivorrLocalizations l = HivorrLocalizations(
        en,
        const <String, String>{},
        const Locale('en'),
      );
      expect(l.translate('common.ok'), 'OK');
      expect(l.translate('app.title'), 'Hivorr');
    });
  });

  group('Localization integration — language switching', () {
    testWidgets('LocaleProvider emits a new locale and translations update',
        (WidgetTester tester) async {
      final LocaleProvider provider = LocaleProvider(
        config: integrationConfig,
        storage: FakeStorageEngine(),
      );
      await provider.setLocale(const Locale('en'));

      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>.value(
          value: provider,
          child: _localizedApp(
            provider,
            Builder(
              builder: (BuildContext c) =>
                  Text(c.tr(TranslationKeys.commonOk)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);

      // Switch to the second supported locale.
      await provider.setLocale(const Locale('fr'));
      await tester.pumpAndSettle();
      expect(find.text('DACCORD'), findsOneWidget);
    });
  });

  group('Localization integration — typed key access', () {
    test('resolves typed TranslationKeys constants to correct values',
        () async {
      final Map<String, String> en =
          await service.loadTranslations(const Locale('en'));
      final HivorrLocalizations l = HivorrLocalizations(
        en,
        const <String, String>{},
        const Locale('en'),
      );

      expect(l.translate(TranslationKeys.commonOk), 'OK');
      expect(l.translate(TranslationKeys.commonCancel), 'Cancel');
      expect(l.translate(TranslationKeys.appTitle), 'Hivorr');
      expect(l.translate(TranslationKeys.authLoginTitle), 'Sign In');
      expect(l.translate(TranslationKeys.errorServer),
          'A server error occurred. Please try again later.');
    });
  });

  group('Localization integration — pluralization', () {
    test('real service selects correct CLDR forms for 0 / 1 / 2+', () {
      final Map<String, String> en = <String, String>{
        'common.itemCount.zero': 'No items',
        'common.itemCount.one': '1 item',
        'common.itemCount.other': '{count} items',
      };

      // Raw form selection via the real service API.
      expect(
        service.resolvePlural(
          'common.itemCount',
          0,
          en,
          null,
          locale: const Locale('en'),
        ),
        'No items',
      );
      expect(
        service.resolvePlural(
          'common.itemCount',
          1,
          en,
          null,
          locale: const Locale('en'),
        ),
        '1 item',
      );
      expect(
        service.resolvePlural(
          'common.itemCount',
          2,
          en,
          null,
          locale: const Locale('en'),
        ),
        '{count} items',
      );
    });

    test('widget plural accessor interpolates count into the form', () {
      final HivorrLocalizations l = HivorrLocalizations(
        const <String, String>{},
        <String, String>{
          'common.itemCount.zero': 'No items',
          'common.itemCount.one': '1 item',
          'common.itemCount.other': '{count} items',
        },
        const Locale('en'),
      );

      expect(l.plural(TranslationKeys.commonItemCount, 0), 'No items');
      expect(l.plural(TranslationKeys.commonItemCount, 1), '1 item');
      expect(l.plural(TranslationKeys.commonItemCount, 2), '2 items');
      expect(l.plural(TranslationKeys.commonItemCount, 5), '5 items');
    });
  });

  group('Localization integration — missing key fallback', () {
    test('returns the key itself when absent in active and fallback',
        () async {
      final Map<String, String> en =
          await service.loadTranslations(const Locale('en'));
      final HivorrLocalizations l = HivorrLocalizations(
        en,
        const <String, String>{},
        const Locale('en'),
      );

      const String missing = 'common.welcome';
      expect(l.translate(missing), missing);
    });

    test('falls back to the fallback table when missing in active', () {
      final HivorrLocalizations l = HivorrLocalizations(
        const <String, String>{},
        <String, String>{'common.ok': 'OK'},
        const Locale('en'),
      );

      expect(l.translate(TranslationKeys.commonOk), 'OK');
    });
  });

  group('Localization integration — widget via pumpApp harness', () {
    testWidgets('rendered text matches and updates on locale switch',
        (WidgetTester tester) async {
      final LocaleProvider provider = LocaleProvider(
        config: integrationConfig,
        storage: FakeStorageEngine(),
      );
      await provider.setLocale(const Locale('en'));

      await pumpApp(
        tester,
        _localizedApp(
          provider,
          Builder(
            builder: (BuildContext c) => Text(c.tr(TranslationKeys.commonOk)),
          ),
        ),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<LocaleProvider>.value(value: provider),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);

      await provider.setLocale(const Locale('fr'));
      await tester.pumpAndSettle();
      expect(find.text('DACCORD'), findsOneWidget);
    });
  });
}
