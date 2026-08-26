import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/app_bootstrap.dart';

import '../../test_helpers.dart';

void main() {
  group('AppBootstrap.initialize', () {
    test('wires config, api, and auth layers on success', () async {
      final result = await AppBootstrap.initialize(
        loadConfig: fakeLoadConfig,
        initializeApi: fakeInitializeApi,
        initializeAuthLayer: fakeInitializeAuthLayer,
      );
      expect(result.appConfig, isNotNull);
      expect(result.apiLayer, isNotNull);
      expect(result.authLayer.provider, isA<FakeAuthProvider>());
    });

    test('propagates initialization failures (fail-closed)', () {
      expect(
        () => AppBootstrap.initialize(
          loadConfig: fakeLoadConfig,
          initializeApi: (_) => throw Exception('boom'),
          initializeAuthLayer: fakeInitializeAuthLayer,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
