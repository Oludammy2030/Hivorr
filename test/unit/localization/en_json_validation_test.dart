import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> json;

  setUpAll(() {
    final File file = File('assets/translations/en.json');
    json = Map<String, dynamic>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
  });

  group('en.json structure', () {
    test('is valid JSON with a non-empty string map', () {
      expect(json, isNotEmpty);
      for (final MapEntry<String, dynamic> entry in json.entries) {
        expect(entry.value, isA<String>(), reason: '${entry.key} not a string');
      }
    });

    test('all values are non-empty strings', () {
      for (final MapEntry<String, dynamic> entry in json.entries) {
        final String value = entry.value as String;
        expect(value.isNotEmpty, isTrue, reason: 'empty value for ${entry.key}');
      }
    });

    test('placeholder syntax is well-formed', () {
      final RegExp placeholder = RegExp(r'\{([^}]+)\}');
      for (final MapEntry<String, dynamic> entry in json.entries) {
        final String value = entry.value as String;
        for (final Match m in placeholder.allMatches(value)) {
          final String name = m.group(1)!;
          expect(name, matches(RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$')),
              reason: 'malformed placeholder {$name} in ${entry.key}');
        }
      }
    });

    test('every plural group includes an .other form', () {
      const List<String> categories = <String>[
        'zero',
        'one',
        'two',
        'few',
        'many',
        'other'
      ];
      final Map<String, Set<String>> groups = <String, Set<String>>{};
      for (final String key in json.keys) {
        final int dot = key.lastIndexOf('.');
        if (dot == -1) continue;
        final String suffix = key.substring(dot + 1);
        if (categories.contains(suffix)) {
          final String base = key.substring(0, dot);
          groups.putIfAbsent(base, () => <String>{}).add(suffix);
        }
      }
      for (final MapEntry<String, Set<String>> group in groups.entries) {
        expect(group.value.contains('other'), isTrue,
            reason: 'plural group "${group.key}" missing .other form');
      }
    });

    test('common.itemCount has zero, one, and other forms', () {
      expect(json.containsKey('common.itemCount.zero'), isTrue);
      expect(json.containsKey('common.itemCount.one'), isTrue);
      expect(json.containsKey('common.itemCount.other'), isTrue);
    });
  });
}
