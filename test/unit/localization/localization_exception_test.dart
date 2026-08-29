import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/localization/localization_exception.dart';

void main() {
  group('LocalizationException', () {
    test('preserves the message', () {
      const LocalizationException e = LocalizationException('boom');
      expect(e.message, 'boom');
    });

    test('preserves optional key and locale', () {
      const LocalizationException e = LocalizationException(
        'boom',
        key: 'common.ok',
        locale: Locale('en'),
      );
      expect(e.key, 'common.ok');
      expect(e.locale?.languageCode, 'en');
    });

    test('toString includes available fields', () {
      const LocalizationException e = LocalizationException(
        'boom',
        key: 'common.ok',
        locale: Locale('en'),
      );
      final String str = e.toString();
      expect(str, contains('boom'));
      expect(str, contains('common.ok'));
      expect(str, contains('en'));
    });
  });
}
