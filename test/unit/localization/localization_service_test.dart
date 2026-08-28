import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/localization_exception.dart';
import 'package:hivorr/core/localization/localization_service.dart';
import 'package:hivorr/core/localization/supported_locales.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final HivorrLocalizationService service = const HivorrLocalizationService();

  group('HivorrLocalizationService.loadTranslations', () {
    test('loads en.json into a non-empty flat map', () async {
      final Map<String, String> map =
          await service.loadTranslations(HivorrSupportedLocales.defaultLocale);
      expect(map, isNotEmpty);
      expect(map['common.ok'], 'OK');
      expect(map['app.title'], 'Hivorr');
    });

    test('throws LocalizationException for a missing locale file', () {
      expect(
        () => service.loadTranslations(const Locale('zz')),
        throwsA(isA<LocalizationException>()),
      );
    });

    test('parseTranslationJson throws for malformed JSON', () {
      expect(
        () => HivorrLocalizationService.parseTranslationJson(
          'this is not json',
          HivorrSupportedLocales.defaultLocale,
        ),
        throwsA(isA<LocalizationException>()),
      );
    });
  });

  group('HivorrLocalizationService.resolve', () {
    const Map<String, String> active = <String, String>{'a': 'A'};
    const Map<String, String> fallback = <String, String>{'a': 'FA', 'b': 'FB'};

    test('returns the active value when present', () {
      expect(service.resolve('a', active, fallback), 'A');
    });

    test('falls back to the fallback map when missing in active', () {
      expect(service.resolve('b', active, fallback), 'FB');
    });

    test('returns the key name when absent in both', () {
      expect(service.resolve('missing', active, fallback), 'missing');
    });
  });

  group('HivorrLocalizationService.interpolate', () {
    test('replaces a single placeholder', () {
      expect(
        service.interpolate('Hello {name}', <String, String>{'name': 'World'}),
        'Hello World',
      );
    });

    test('replaces multiple placeholders', () {
      expect(
        service.interpolate(
          '{a} {b}',
          <String, String>{'a': '1', 'b': '2'},
        ),
        '1 2',
      );
    });

    test('returns template unchanged for empty params', () {
      expect(service.interpolate('{x}', <String, String>{}), '{x}');
    });

    test('leaves unknown placeholders untouched', () {
      expect(
        service.interpolate('{a} {b}', <String, String>{'a': '1'}),
        '1 {b}',
      );
    });

    test('ignores extra params not present in template', () {
      expect(
        service.interpolate('{a}', <String, String>{'a': '1', 'extra': 'x'}),
        '1',
      );
    });

    test('does not recursively interpolate param values', () {
      expect(
        service.interpolate('{a}', <String, String>{'a': '{b}'}),
        '{b}',
      );
    });
  });

  group('HivorrLocalizationService.resolvePlural', () {
    const Map<String, String> t = <String, String>{
      'x.zero': 'none',
      'x.one': '1',
      'x.other': '{count}',
    };

    test('selects .one for count=1', () {
      expect(service.resolvePlural('x', 1, t, null), '1');
    });

    test('selects .zero for count=0 when present', () {
      expect(service.resolvePlural('x', 0, t, null), 'none');
    });

    test('selects .other for count=2 and count=5', () {
      expect(service.resolvePlural('x', 2, t, null), '{count}');
      expect(service.resolvePlural('x', 5, t, null), '{count}');
    });

    test('falls back to .other when the specific form is missing', () {
      const Map<String, String> onlyOther =
          <String, String>{'x.other': 'many'};
      expect(service.resolvePlural('x', 1, onlyOther, null), 'many');
    });
  });
}
