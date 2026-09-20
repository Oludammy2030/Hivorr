import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';

import '../../support/fakes/fake_portfolio.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PortfolioRepositoryImpl
  // ---------------------------------------------------------------------------
  group('PortfolioRepositoryImpl', () {
    test('returns the PublicProfile on a successful fetch', () async {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource();
      final PortfolioRepositoryImpl repo = PortfolioRepositoryImpl(
        remote: remote,
      );

      final PublicProfile? profile = await repo.getPublicProfile('entity-1');

      expect(profile, isNotNull);
      expect(profile!.entityId, 'entity-1');
      expect(profile.displayName, 'Ada Lovelace');
      expect(remote.lastEntityId, 'entity-1');
    });

    test('returns null when the server raises PLT004 (not-found)', () async {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource(
            error: const ApiException(
              kind: ApiExceptionKind.notFound,
              message: 'not found',
              code: 'PLT004',
            ),
          );
      final PortfolioRepositoryImpl repo = PortfolioRepositoryImpl(
        remote: remote,
      );

      final PublicProfile? profile = await repo.getPublicProfile('unknown');

      expect(profile, isNull);
    });

    test('rethrows ApiException for non-PLT004 server errors', () async {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource(
            error: const ApiException(
              kind: ApiExceptionKind.server,
              message: 'internal error',
              code: 'PLT999',
            ),
          );
      final PortfolioRepositoryImpl repo = PortfolioRepositoryImpl(
        remote: remote,
      );

      expect(
        () => repo.getPublicProfile('entity-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.server,
              )
              .having((ApiException e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('forwards validation errors without swallowing', () async {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource(
            error: const ApiException(
              kind: ApiExceptionKind.validation,
              message: 'bad id',
              code: 'PLT003',
            ),
          );
      final PortfolioRepositoryImpl repo = PortfolioRepositoryImpl(
        remote: remote,
      );

      expect(
        () => repo.getPublicProfile('bad-id'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.validation,
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PortfolioProvider
  // ---------------------------------------------------------------------------
  group('PortfolioProvider', () {
    test('starts in idle state with no profile', () {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource();
      final PortfolioProvider provider = PortfolioProvider(
        repository: PortfolioRepositoryImpl(remote: remote),
      );

      expect(provider.state, PortfolioLoadState.idle);
      expect(provider.profile, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.lastError, isNull);

      provider.dispose();
    });

    test('transitions idle → loaded with profile on success', () async {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource();
      final PortfolioProvider provider = PortfolioProvider(
        repository: PortfolioRepositoryImpl(remote: remote),
      );
      final List<PortfolioLoadState> states = <PortfolioLoadState>[];
      provider.addListener(() => states.add(provider.state));

      final PublicProfile? profile = await provider.load('entity-1');

      expect(profile, isNotNull);
      expect(profile!.entityId, 'entity-1');
      expect(provider.state, PortfolioLoadState.loaded);
      expect(provider.isLoaded, isTrue);
      expect(states, contains(PortfolioLoadState.loading));
      expect(states, contains(PortfolioLoadState.loaded));
      provider.dispose();
    });

    test('transitions idle → error with lastError on ApiException', () async {
      final ApiException failure = const ApiException(
        kind: ApiExceptionKind.server,
        message: 'boom',
        code: 'PLT999',
      );
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource(error: failure);
      final PortfolioProvider provider = PortfolioProvider(
        repository: PortfolioRepositoryImpl(remote: remote),
      );

      await expectLater(
        provider.load('entity-1'),
        throwsA(isA<ApiException>()),
      );

      expect(provider.state, PortfolioLoadState.error);
      expect(provider.lastError, failure);
      provider.dispose();
    });

    test(
      'returns null profile for PLT004 (not-found) without error state',
      () async {
        final FakePortfolioRemoteDataSource remote =
            FakePortfolioRemoteDataSource(
              error: const ApiException(
                kind: ApiExceptionKind.notFound,
                message: 'not found',
                code: 'PLT004',
              ),
            );
        final PortfolioProvider provider = PortfolioProvider(
          repository: PortfolioRepositoryImpl(remote: remote),
        );

        final PublicProfile? profile = await provider.load('unknown');

        expect(profile, isNull);
        expect(provider.state, PortfolioLoadState.loaded);
        expect(provider.lastError, isNull);
        provider.dispose();
      },
    );

    test('is a no-op while a load is in flight', () async {
      final Completer<void> gate = Completer<void>();
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource()..gate = gate;
      final PortfolioProvider provider = PortfolioProvider(
        repository: PortfolioRepositoryImpl(remote: remote),
      );

      final Future<PublicProfile?> first = provider.load('entity-1');
      // Second call while first is in flight: returns early, no second fetch.
      final PublicProfile? secondResult = await provider.load('entity-1');

      expect(remote.callCount, 1);
      expect(provider.isLoading, isTrue);
      expect(
        secondResult,
        isNull,
        reason: 'in-flight re-entry returns the current (not loaded) profile',
      );

      gate.complete();
      await first;

      expect(provider.state, PortfolioLoadState.loaded);
      provider.dispose();
    });

    test('clears a prior error when a later load succeeds', () async {
      final FakePortfolioRemoteDataSource remote =
          FakePortfolioRemoteDataSource(
            error: const ApiException(
              kind: ApiExceptionKind.server,
              message: 'offline',
              code: 'PLT999',
            ),
          );
      final PortfolioProvider provider = PortfolioProvider(
        repository: PortfolioRepositoryImpl(remote: remote),
      );

      // First call fails with a re-thrown server error.
      await expectLater(
        () => provider.load('entity-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
      expect(provider.state, PortfolioLoadState.error);

      // Second call succeeds.
      remote.error = null;
      await provider.load('entity-1');
      expect(provider.state, PortfolioLoadState.loaded);
      expect(provider.lastError, isNull);
      provider.dispose();
    });
  });
}
