import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/shared.dart';

class _Store with ChangeNotifier, LoadingStateMixin {}

void main() {
  group('LoadingStateMixin', () {
    test('runWithLoading transitions state and clears error', () async {
      final _Store store = _Store();
      bool ran = false;
      await store.runWithLoading(() async {
        ran = true;
      });
      expect(ran, isTrue);
      expect(store.isLoading, isFalse);
      expect(store.hasError, isFalse);
      expect(store.errorMessage, isNull);
    });

    test('captures errors into errorMessage', () async {
      final _Store store = _Store();
      await store.runWithLoading(() async {
        throw Exception('boom');
      });
      expect(store.hasError, isTrue);
      expect(store.errorMessage, contains('boom'));
      expect(store.isLoading, isFalse);
    });

    test('exposes loading flag during run', () async {
      final _Store store = _Store();
      final Future<void> future = store.runWithLoading(() async {
        expect(store.isLoading, isTrue);
      });
      expect(store.isLoading, isTrue);
      await future;
      expect(store.isLoading, isFalse);
    });
  });
}
