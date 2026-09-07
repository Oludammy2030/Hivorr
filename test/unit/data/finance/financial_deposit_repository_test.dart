import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/financial_deposit_remote_data_source.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/models/deposit_dto.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository_impl.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

class FakeDepositRemote implements FinancialDepositRemoteDataSource {
  FakeDepositRemote({List<DepositDto>? seed}) : rows = seed ?? <DepositDto>[];

  final List<DepositDto> rows;
  ApiException? nextError;
  int listCallCount = 0;

  @override
  Future<List<DepositDto>> listDeposits() async {
    listCallCount++;
    if (nextError != null) throw nextError!;
    return rows;
  }
}

void main() {
  group('FinancialDepositRepositoryImpl.listDeposits', () {
    test('maps DTO rows into Deposit entities', () async {
      final remote = FakeDepositRemote(
        seed: <DepositDto>[
          DepositDto(
            id: 'dep-1',
            currencyCode: 'NGN',
            amount: 150000,
            nameMatchStatus: 'matched',
            payerName: 'John Doe',
            status: 'credited',
          ),
        ],
      );
      final repo = FinancialDepositRepositoryImpl(remote: remote);

      final List<Deposit> deposits = await repo.listDeposits();

      expect(remote.listCallCount, 1);
      expect(deposits, hasLength(1));
      expect(deposits.single.id, 'dep-1');
      expect(deposits.single.nameMatchStatus, DepositNameMatchStatus.matched);
      expect(deposits.single.isCredited, isTrue);
      expect(deposits.single.payerName, 'John Doe');
    });

    test('returns an empty list when no deposits exist', () async {
      final repo = FinancialDepositRepositoryImpl(
        remote: FakeDepositRemote(),
      );

      expect(await repo.listDeposits(), isEmpty);
    });

    test('surfaces remote failures unchanged', () async {
      const ApiException failure = ApiException(
        kind: ApiExceptionKind.server,
        message: 'deposits down',
        code: 'PLT999',
      );
      final remote = FakeDepositRemote()..nextError = failure;
      final repo = FinancialDepositRepositoryImpl(remote: remote);

      await expectLater(
        repo.listDeposits(),
        throwsA(same(failure)),
      );
    });
  });
}