import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/localization/translation_keys.dart';

const List<String> _allKeys = <String>[
  TranslationKeys.commonOk,
  TranslationKeys.commonCancel,
  TranslationKeys.commonSave,
  TranslationKeys.commonDelete,
  TranslationKeys.commonEdit,
  TranslationKeys.commonDone,
  TranslationKeys.commonRetry,
  TranslationKeys.commonLoading,
  TranslationKeys.commonError,
  TranslationKeys.commonSuccess,
  TranslationKeys.commonWarning,
  TranslationKeys.commonNoData,
  TranslationKeys.commonSearch,
  TranslationKeys.commonClose,
  TranslationKeys.commonBack,
  TranslationKeys.commonNext,
  TranslationKeys.commonYes,
  TranslationKeys.commonNo,
  TranslationKeys.commonItemCount,
  TranslationKeys.authLoginTitle,
  TranslationKeys.authSignupTitle,
  TranslationKeys.authEmail,
  TranslationKeys.authPassword,
  TranslationKeys.authForgotPassword,
  TranslationKeys.authLoginButton,
  TranslationKeys.authSignupButton,
  TranslationKeys.authLogoutButton,
  TranslationKeys.authNoAccount,
  TranslationKeys.authHasAccount,
  TranslationKeys.errorGeneric,
  TranslationKeys.errorNetwork,
  TranslationKeys.errorTimeout,
  TranslationKeys.errorUnauthorized,
  TranslationKeys.errorNotFound,
  TranslationKeys.errorServer,
  TranslationKeys.validationRequired,
  TranslationKeys.validationEmail,
  TranslationKeys.validationPhone,
  TranslationKeys.validationMinLength,
  TranslationKeys.validationMaxLength,
  TranslationKeys.validationPasswordStrength,
  TranslationKeys.appTitle,
  TranslationKeys.appTagline,
];

void main() {
  group('TranslationKeys', () {
    test('all values are non-empty strings', () {
      for (final String value in _allKeys) {
        expect(value, isA<String>());
        expect(value.isNotEmpty, isTrue, reason: 'empty key value');
      }
    });

    test('all values follow the namespace.keyName convention', () {
      for (final String value in _allKeys) {
        expect(
          value.startsWith(RegExp(r'^[a-z]+(\.[a-zA-Z0-9]+)+$')),
          isTrue,
          reason: 'key "$value" violates namespace.keyName convention',
        );
      }
    });

    test('no duplicate key values', () {
      final Set<String> seen = <String>{};
      for (final String value in _allKeys) {
        expect(seen.contains(value), isFalse,
            reason: 'duplicate key value: $value');
        seen.add(value);
      }
    });

    test('every key has a corresponding entry in en.json', () {
      final File file = File('assets/translations/en.json');
      expect(file.existsSync(), isTrue);
      final String raw = file.readAsStringSync();
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final String key in _allKeys) {
        final bool present = json.containsKey(key) ||
            json.keys.any((String k) => k.startsWith('$key.'));
        expect(present, isTrue, reason: 'missing translation for $key');
      }
    });
  });
}
