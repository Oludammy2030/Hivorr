import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/security/token/token_rotation_helper.dart';
import 'package:hivorr/core/storage/secure_token_store.dart';

import '../../storage/fakes.dart';
import 'fakes.dart';

void main() {
  group('TokenRotationHelper', () {
    late FakeAccessTokenProvider provider;
    late InMemorySecureStorage storage;
    late SecureTokenStore tokenStore;
    late TokenRotationHelper helper;

    setUp(() {
      provider = FakeAccessTokenProvider(currentToken: 'current-token');
      storage = InMemorySecureStorage();
      tokenStore = SecureTokenStore(storage);
      helper = TokenRotationHelper(
        accessTokenProvider: provider,
        tokenStore: tokenStore,
      );
    });

    test('rotateIfNeeded returns current token without refresh when far from '
        'expiry', () async {
      final DateTime future = DateTime.now().add(const Duration(days: 1));
      final String? result = await helper.rotateIfNeeded(future);

      expect(result, 'current-token');
      expect(provider.refreshCalls, 0);
      expect(await tokenStore.readAccessToken(), isNull);
    });

    test('rotateIfNeeded refreshes and persists when expiry is null', () async {
      final String? result = await helper.rotateIfNeeded(null);

      expect(result, 'refreshed-token');
      expect(provider.refreshCalls, 1);
      expect(await tokenStore.readAccessToken(), 'refreshed-token');
    });

    test('rotateIfNeeded refreshes when within expiry buffer', () async {
      final DateTime soon =
          DateTime.now().add(const Duration(minutes: 1));
      final String? result = await helper.rotateIfNeeded(soon);

      expect(result, 'refreshed-token');
      expect(provider.refreshCalls, 1);
    });

    test('onRefresh forces a refresh regardless of expiry', () async {
      final DateTime far = DateTime.now().add(const Duration(days: 1));
      // Pre-condition: not expired, so rotateIfNeeded would skip.
      expect(await helper.rotateIfNeeded(far), 'current-token');

      final String? result = await helper.onRefresh();
      expect(result, 'refreshed-token');
      expect(provider.refreshCalls, 1);
    });

    test('concurrent refreshes share a single refresh call', () async {
      provider = FakeAccessTokenProvider(
        currentToken: 'current-token',
        nextToken: 'refreshed-token',
        refreshDelay: const Duration(milliseconds: 50),
      );
      helper = TokenRotationHelper(
        accessTokenProvider: provider,
        tokenStore: tokenStore,
      );

      final List<String?> results = await Future.wait<String?>(
        <Future<String?>>[
          helper.rotateIfNeeded(null),
          helper.rotateIfNeeded(null),
          helper.rotateIfNeeded(null),
          helper.rotateIfNeeded(null),
          helper.rotateIfNeeded(null),
        ],
      );

      expect(results, everyElement('refreshed-token'));
      expect(provider.refreshCalls, 1);
      expect(await tokenStore.readAccessToken(), 'refreshed-token');
    });

    test('rotateIfNeeded throws ApiException when refresh throws', () async {
      provider = FakeAccessTokenProvider(
        currentToken: 'current-token',
        refreshError: Exception('network down'),
      );
      helper = TokenRotationHelper(
        accessTokenProvider: provider,
        tokenStore: tokenStore,
      );

      await expectLater(
        helper.rotateIfNeeded(null),
        throwsA(isA<ApiException>()),
      );
      expect(provider.refreshCalls, 1);
      expect(await tokenStore.readAccessToken(), isNull);
    });

    test('rotateIfNeeded throws ApiException when refresh returns no token',
        () async {
      provider = FakeAccessTokenProvider(
        currentToken: 'current-token',
        nextToken: null,
      );
      helper = TokenRotationHelper(
        accessTokenProvider: provider,
        tokenStore: tokenStore,
      );

      await expectLater(
        helper.rotateIfNeeded(null),
        throwsA(isA<ApiException>()),
      );
      expect(await tokenStore.readAccessToken(), isNull);
    });

    test('does not write when the refreshed token is unchanged', () async {
      provider = FakeAccessTokenProvider(
        currentToken: 'same-token',
        nextToken: 'same-token',
      );
      helper = TokenRotationHelper(
        accessTokenProvider: provider,
        tokenStore: tokenStore,
      );

      final String? result = await helper.rotateIfNeeded(null);
      expect(result, 'same-token');
      expect(provider.refreshCalls, 1);
      expect(await tokenStore.readAccessToken(), isNull);
    });
  });
}
