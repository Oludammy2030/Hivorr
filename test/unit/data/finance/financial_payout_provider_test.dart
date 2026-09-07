import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';

import '../../../support/fakes/finance/fake_financial_payout_repository.dart';

void main() {
  FinancialPayoutProvider build(FakeFinancialPayoutRepository repo) =>
      FinancialPayoutProvider(service: FinancialPayoutService(repository: repo));

  group('FinancialPayoutProvider load lifecycle', () {
    test('starts idle empty with no error', () {
      final provider = build(FakeFinancialPayoutRepository());
      expect(provider.loadState, PayoutLoadState.idle);
      expect(provider.accounts, isEmpty);
      expect(provider.isLoaded, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.lastError, isNull);
      expect(provider.isBinding, isFalse);
      expect(provider.isWithdrawing, isFalse);
      provider.dispose();
    });

    test('load() surfaces the mirror and enters loaded state', () async {
      final repo = FakeFinancialPayoutRepository(
        seed: <PayoutAccount>[
          FakeFinancialPayoutRepository.verified(),
        ],
      );
      final provider = build(repo);

      await provider.load();

      expect(provider.loadState, PayoutLoadState.loaded);
      expect(provider.isLoaded, isTrue);
      expect(provider.accounts, hasLength(1));
      expect(repo.listCallCount, 1);
      provider.dispose();
    });

    test('load() stores a typed ApiException and enters error state', () async {
      const ApiException failure = ApiException(
        kind: ApiExceptionKind.server,
        message: 'load down',
        code: 'PLT999',
      );
      final repo = FakeFinancialPayoutRepository()..nextError = failure;
      final provider = build(repo);

      await provider.load();

      expect(provider.loadState, PayoutLoadState.error);
      expect(provider.isLoaded, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.lastError, same(failure));
      provider.dispose();
    });
  });

  group('FinancialPayoutProvider bind', () {
    test('appends the bound account and sets a success note', () async {
      final repo = FakeFinancialPayoutRepository();
      final provider = build(repo);

      final PayoutAccount? account = await provider.bindAccount(
        currencyCode: 'NGN',
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
      );

      expect(account, isNotNull);
      expect(provider.accounts, hasLength(1));
      expect(provider.accounts.first.id, account!.id);
      expect(provider.successMessage, contains('verification is pending'));
      expect(provider.lastError, isNull);
      expect(provider.isBinding, isFalse);
      expect(provider.takeSuccessMessage(), isNotNull);
      expect(provider.successMessage, isNull);
      provider.dispose();
    });

    test('does not duplicate accounts already present', () async {
      final repo = FakeFinancialPayoutRepository();
      final provider = build(repo);
      await provider.bindAccount(
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
      );
      repo.nextError = null;

      await provider.bindAccount(
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
      );

      expect(provider.accounts, hasLength(1));
      provider.dispose();
    });

    test('stores a typed ApiException and returns null on failure', () async {
      const ApiException conflict = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Account already bound.',
        code: 'PLT005',
      );
      final repo = FakeFinancialPayoutRepository()..nextError = conflict;
      final provider = build(repo);

      final PayoutAccount? account = await provider.bindAccount(
        currencyCode: 'NGN',
        bankName: 'B',
        accountNumber: '0123456789',
        accountName: 'N',
      );

      expect(account, isNull);
      expect(provider.lastError, same(conflict));
      expect(provider.accounts, isEmpty);
      provider.dispose();
    });
  });

  group('FinancialPayoutProvider withdraw', () {
    test('sets a success note and returns the server result', () async {
      final repo = FakeFinancialPayoutRepository()
        ..nextWithdrawalResult = const WithdrawalResult(
          payoutId: 'pay-9',
          amount: 50000,
          fee: 0,
          netAmount: 50000,
          cashoutRemaining: 450000,
        );
      final provider = build(repo);

      final WithdrawalResult? result =
          await provider.withdraw(payoutAccountId: 'acc-1', amount: 50000);

      expect(result, isNotNull);
      expect(result!.payoutId, 'pay-9');
      expect(provider.successMessage, 'Withdrawal initiated.');
      expect(provider.isWithdrawing, isFalse);
      provider.dispose();
    });

    test('stores a typed PLT006 failure and returns null', () async {
      const ApiException insufficient = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Insufficient balance.',
        code: 'PLT006',
      );
      final repo = FakeFinancialPayoutRepository()..nextError = insufficient;
      final provider = build(repo);

      final WithdrawalResult? result =
          await provider.withdraw(payoutAccountId: 'acc-1', amount: 50000);

      expect(result, isNull);
      expect(provider.lastError, same(insufficient));
      expect(provider.successMessage, isNull);
      provider.dispose();
    });
  });
}