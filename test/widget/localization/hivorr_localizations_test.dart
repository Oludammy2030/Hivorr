import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/hivorr_localizations.dart';
import 'package:hivorr/core/localization/locale_provider.dart';
import 'package:hivorr/core/localization/localization_config.dart';
import 'package:hivorr/core/localization/localization_extension.dart';
import 'package:hivorr/core/localization/translation_keys.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

const LocalizationConfig testConfig = LocalizationConfig(
  defaultLocale: Locale('en'),
  fallbackLocale: Locale('en'),
  supportedLocales: <Locale>[Locale('en'), Locale('fr')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Real asset load — kept as the FIRST test so rootBundle is still alive.
  testWidgets('HivorrLocalizations.delegate.load builds an en instance',
      (WidgetTester tester) async {
    final HivorrLocalizations l =
        await HivorrLocalizations.delegate.load(Locale('en'));
    expect(l.translate(TranslationKeys.commonOk), 'OK');
  });

  testWidgets('HivorrLocalizations(...) builds a usable instance',
      (WidgetTester tester) async {
    final HivorrLocalizations l = HivorrLocalizations(
      <String, String>{'common.cancel': 'Cancel'},
      <String, String>{'common.ok': 'OK'},
      Locale('fr'),
    );
    expect(l.translate(TranslationKeys.commonOk), 'OK');
    expect(l.translate(TranslationKeys.commonCancel), 'Cancel');
  });

  testWidgets('translate interpolates params', (WidgetTester tester) async {
    final HivorrLocalizations l = HivorrLocalizations(
      <String, String>{},
      <String, String>{'validation.required': '{field} is required'},
      Locale('en'),
    );
    expect(
      l.translate(
        TranslationKeys.validationRequired,
        params: <String, String>{'field': 'Email'},
      ),
      'Email is required',
    );
  });

  testWidgets('resolve returns the key when the lookup misses',
      (WidgetTester tester) async {
    final HivorrLocalizations l = HivorrLocalizations(
      <String, String>{},
      <String, String>{},
      Locale('en'),
    );
    expect(l.translate(TranslationKeys.commonOk), TranslationKeys.commonOk);
  });

  testWidgets('plural selects the correct form', (WidgetTester tester) async {
    final HivorrLocalizations l = HivorrLocalizations(
      <String, String>{},
      <String, String>{
        'common.itemCount.zero': 'No items',
        'common.itemCount.one': '1 item',
        'common.itemCount.other': '{count} items',
      },
      Locale('en'),
    );
    expect(l.plural(TranslationKeys.commonItemCount, 0), 'No items');
    expect(l.plural(TranslationKeys.commonItemCount, 1), '1 item');
    expect(l.plural(TranslationKeys.commonItemCount, 3), '3 items');
  });

  testWidgets('rebuilds widget tree when the locale provider changes',
      (WidgetTester tester) async {
    final LocaleProvider provider = LocaleProvider(
      config: testConfig,
      storage: FakeStorageEngine(),
    );
    await provider.setLocale(const Locale('en'));
    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: provider,
        child: Consumer<LocaleProvider>(
          builder: (BuildContext context, LocaleProvider p, _) => MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              FakeLocalizationsDelegate(),
              GlobalWidgetsLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const <Locale>[Locale('en'), Locale('fr')],
            locale: p.currentLocale,
            home: Builder(
              builder: (BuildContext c) => Text(c.tr(TranslationKeys.commonOk)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);

    await provider.setLocale(const Locale('fr'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('DACCORD'), findsOneWidget);
  });
}
