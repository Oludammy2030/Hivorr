import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/financial_payout_remote_data_source.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/local/payout_account_local_store.dart';
import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';
import 'package:hivorr/data/repositories/financial_payout_repository_impl.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';

class FakePayoutRemote implements FinancialPayoutRemoteDataSource {
  FakePayoutRemote({
    this.bindResult = const PayoutBindDto(
      payoutAccountId: 'acc-new',
      currencyCode: 'NGN',
      status: 'pending',
    ),
    this.withdrawResult = const WithdrawalDto(
      payoutId: 'pay-1',
      amount: 50000,
      fee: 0,
      netAmount: 50000,
      cashoutRemaining: 450000,
    ),
  });

  PayoutBindDto bindResult;
  WithdrawalDto withdrawResult;
  ApiException? nextError;
  int bindCallCount = 0;
  int withdrawCallCount = 0;
  String? lastWithdrawalAccountId;
  double? lastWithdrawalAmount;

  @override
  Future<PayoutBindDto> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    bindCallCount++;
    if (nextError != null) throw nextError!;
    return bindResult;
  }

  @override
  Future<WithdrawalDto> withdraw({
    required String payoutAccountId,
    required double amount,
  }) async {
    withdrawCallCount++;
    if (nextError != null) throw nextError!;
    lastWithdrawalAccountId = payoutAccountId;
    lastWithdrawalAmount = amount;
    return withdrawResult;
  }
}

void main() {
  FinancialPayoutRepositoryImpl build({FakePayoutRemote? remote}) {
    final FakePayoutRemote r = remote ?? FakePayoutRemote();
    return FinancialPayoutRepositoryImpl(
      remote: r,
      store: InMemoryPayoutAccountLocalStore(),
    );
  }

  group('FinancialPayoutRepositoryImpl.bindAccount', () {
    test('upper-cases supported currencies before the RPC', () async {
      final remote = FakePayoutRemote();
      final repo = FinancialPayoutRepositoryImpl(
        remote: remote,
        store: InMemoryPayoutAccountLocalStore(),
      );

      final PayoutAccount account = await repo.bindAccount(
        currencyCode: 'ngn',
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
      );

      expect(remote.bindCallCount, 1);
      expect(account.id, 'acc-new');
      expect(account.currencyCode, 'NGN');
      expect(account.status, PayoutAccountStatus.pending);
    });

    test('rejects unsupported currencies with PLT003 before the RPC', () async {
      final remote = FakePayoutRemote();
      final repo = build(remote: remote);

      await expectLater(
        repo.bindAccount(
          currencyCode: 'EUR',
          bankName: 'X',
          accountNumber: '1234567890',
          accountName: 'X',
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT003')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              ),
        ),
      );
      expect(remote.bindCallCount, 0);
    });

    test('rejects a bad NUBAN with PLT003 before the RPC', () async {
      final remote = FakePayoutRemote();
      final repo = build(remote: remote);

      await expectLater(
        repo.bindAccount(
          currencyCode: 'NGN',
          bankName: 'X',
          accountNumber: '123456789',
          accountName: 'X',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.bindCallCount, 0);
    });

    test('persists the bound account into the local display mirror', () async {
      final store = InMemoryPayoutAccountLocalStore();
      final repo = FinancialPayoutRepositoryImpl(
        remote: FakePayoutRemote(),
        store: store,
      );

      await repo.bindAccount(
        currencyCode: 'NGN',
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
      );

      final List<PayoutAccount> mirror = store.readAll();
      expect(mirror, hasLength(1));
      expect(mirror.single.maskedAccountNumber, '***6789');
    });

    test('surfaces remote PLT005 conflicts unchanged', () async {
      const ApiException conflict = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Account already bound.',
        code: 'PLT005',
      );
      final remote = FakePayoutRemote()..nextError = conflict;
      final repo = build(remote: remote);

      await expectLater(
        repo.bindAccount(
          currencyCode: 'NGN',
          bankName: 'X',
          accountNumber: '0123456789',
          accountName: 'X',
        ),
        throwsA(same(conflict)),
      );
    });
  });

  group('FinancialPayoutRepositoryImpl.listPayoutAccounts', () {
    test('returns the local mirrored accounts', () async {
      final store = InMemoryPayoutAccountLocalStore(
        seed: const <PayoutAccount>[
          PayoutAccount(
            id: 'acc-1',
            currencyCode: 'NGN',
            bankName: 'Guaranty Trust',
            accountNumber: '0123456789',
            accountName: 'John Doe',
            status: PayoutAccountStatus.pending,
          ),
        ],
      );
      final repo = FinancialPayoutRepositoryImpl(
        remote: FakePayoutRemote(),
        store: store,
      );

      final List<PayoutAccount> accounts = await repo.listPayoutAccounts();

      expect(accounts, hasLength(1));
      expect(accounts.single.id, 'acc-1');
    });
  });

  group('FinancialPayoutRepositoryImpl.withdraw', () {
    test('rejects amounts <= 0 with PLT003 before the RPC', () async {
      final remote = FakePayoutRemote();
      final store = InMemoryPayoutAccountLocalStore(
        seed: <PayoutAccount>[usableAccount()],
      );
      final repo = FinancialPayoutRepositoryImpl(remote: remote, store: store);

      await expectLater(
        repo.withdraw(payoutAccountId: 'acc-1', amount: 0),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.withdrawCallCount, 0);
    });

    test('rejects an unknown or unverified account with PLT003', () async {
      final remote = FakePayoutRemote();
      final repo = build(remote: remote);

      await expectLater(
        repo.withdraw(payoutAccountId: 'missing', amount: 100),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.withdrawCallCount, 0);
    });

    test('delegates a verified withdrawal to the RPC and maps the result',
        () async {
      final remote = FakePayoutRemote();
      final store = InMemoryPayoutAccountLocalStore(
        seed: <PayoutAccount>[usableAccount()],
      );
      final repo = FinancialPayoutRepositoryImpl(remote: remote, store: store);

      final WithdrawalResult result =
          await repo.withdraw(payoutAccountId: 'acc-1', amount: 50000);

      expect(remote.withdrawCallCount, 1);
      expect(remote.lastWithdrawalAccountId, 'acc-1');
      expect(remote.lastWithdrawalAmount, 50000);
      expect(result.payoutId, 'pay-1');
      expect(result.netAmount, 50000);
      expect(result.cashoutRemaining, 450000);
    });
  });
}

PayoutAccount usableAccount() => PayoutAccount(
      id: 'acc-1',
      currencyCode: 'NGN',
      bankName: 'Guaranty Trust',
      accountNumber: '0123456789',
      accountName: 'John Doe',
      status: PayoutAccountStatus.active,
      isVerified: true,
    );