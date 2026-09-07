import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';

import '../../../support/fakes/finance/fake_financial_deposit_repository.dart';

void main() {
  FinancialDepositProvider build(FakeFinancialDepositRepository repo) =>
      FinancialDepositProvider(
        service: FinancialDepositService(repository: repo),
      );

  group('FinancialDepositProvider load lifecycle', () {
    test('starts idle empty with no error', () {
      final provider = build(FakeFinancialDepositRepository());
      expect(provider.loadState, DepositLoadState.idle);
      expect(provider.deposits, isEmpty);
      expect(provider.isLoaded, isFalse);
      expect(provider.lastError, isNull);
      expect(provider.matchedCount, 0);
      expect(provider.pendingCount, 0);
      expect(provider.mismatchedCount, 0);
      expect(provider.unverifiedCount, 0);
      provider.dispose();
    });

    test('load() exposes deposits and per-status aggregates', () async {
      final repo = FakeFinancialDepositRepository(
        seed: <Deposit>[
          FakeFinancialDepositRepository.matched(),
          FakeFinancialDepositRepository.matched(),
          FakeFinancialDepositRepository.pending(),
        ],
      );
      final provider = build(repo);

      await provider.load();

      expect(provider.loadState, DepositLoadState.loaded);
      expect(provider.isLoading, isFalse);
      expect(provider.deposits, hasLength(3));
      expect(provider.matchedCount, 2);
      expect(provider.pendingCount, 1);
      expect(repo.listCallCount, 1);
      provider.dispose();
    });

    test('load() stores a typed ApiException and enters error state', () async {
      const ApiException failure = ApiException(
        kind: ApiExceptionKind.server,
        message: 'deposits down',
        code: 'PLT999',
      );
      final repo = FakeFinancialDepositRepository()..nextError = failure;
      final provider = build(repo);

      await provider.load();

      expect(provider.loadState, DepositLoadState.error);
      expect(provider.isLoaded, isFalse);
      expect(provider.deposits, isEmpty);
      expect(provider.lastError, same(failure));
      provider.dispose();
    });
  });
}