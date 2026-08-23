import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/security/crypto/sha256.dart';

void main() {
  group('sha256', () {
    test('matches the known empty-string vector', () {
      final Uint8List digest = sha256(<int>[]);
      expect(
        digest.map((int b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('matches the known "abc" vector', () {
      final Uint8List digest = sha256(utf8.encode('abc'));
      expect(
        digest.map((int b) => b.toRadixString(16).padLeft(2, '0')).join(),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('sha256Base64 of empty input', () {
      expect(sha256Base64(<int>[]), '47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=');
    });
  });
}
