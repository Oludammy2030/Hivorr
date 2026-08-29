import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/hivorr_localizations.dart';
import 'package:hivorr/core/localization/locale_provider.dart';
import 'package:hivorr/core/localization/localization_extension.dart';
import 'package:hivorr/core/localization/supported_locales.dart';
import 'package:hivorr/core/localization/translation_keys.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

Widget _buildApp(LocaleProvider provider, Widget home) =>
    ChangeNotifierProvider<LocaleProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          FakeLocalizationsDelegate(),
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: HivorrSupportedLocales.supported,
        locale: provider.currentLocale,
        home: home,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tr returns the correct translation', (WidgetTester tester) async {
    final LocaleProvider provider = FakeLocaleProvider();
    await tester.pumpWidget(
      _buildApp(
        provider,
        Builder(
          builder: (BuildContext c) => Text(c.tr(TranslationKeys.commonOk)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('tr with params returns interpolated text',
      (WidgetTester tester) async {
    final LocaleProvider provider = FakeLocaleProvider();
    await tester.pumpWidget(
      _buildApp(
        provider,
        Builder(
          builder: (BuildContext c) => Text(
            c.tr(
              TranslationKeys.validationRequired,
              params: <String, String>{'field': 'Email'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('plural returns correct forms', (WidgetTester tester) async {
    final LocaleProvider provider = FakeLocaleProvider();
    await tester.pumpWidget(
      _buildApp(
        provider,
        Builder(
          builder: (BuildContext c) {
            final List<int> list = <int>[1, 2, 3];
            return Text(
              c.plural(TranslationKeys.commonItemCount, list.length),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('currentLocale returns the active locale',
      (WidgetTester tester) async {
    final LocaleProvider provider = FakeLocaleProvider();
    await tester.pumpWidget(
      _buildApp(
        provider,
        Builder(
          builder: (BuildContext c) => Text(c.currentLocale.languageCode),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('en'), findsOneWidget);
  });

  testWidgets('l10n returns the active HivorrLocalizations instance',
      (WidgetTester tester) async {
    final LocaleProvider provider = FakeLocaleProvider();
    HivorrLocalizations? captured;
    await tester.pumpWidget(
      _buildApp(
        provider,
        Builder(
          builder: (BuildContext c) {
            captured = c.l10n;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.translate(TranslationKeys.commonOk), 'OK');
  });
}
