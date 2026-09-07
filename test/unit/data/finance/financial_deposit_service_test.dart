import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/finance/fake_financial_deposit_repository.dart';

void main() {
  FinancialDepositService build({
    FakeFinancialDepositRepository? repo,
    HivorrLogger? logger,
  }) =>
      FinancialDepositService(
        repository: repo ?? FakeFinancialDepositRepository(),
        logger: logger,
      );

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test.deposit',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.info),
        PiiRedactor(),
      );

  group('listDeposits', () {
    test('delegates and returns the RLS-scoped list', () async {
      final repo = FakeFinancialDepositRepository(
        seed: <Deposit>[
          FakeFinancialDepositRepository.matched(),
          FakeFinancialDepositRepository.pending(),
        ],
      );
      final sink = RecordingSink();
      final service = build(repo: repo, logger: makeLogger(sink));

      final List<Deposit> deposits = await service.listDeposits();

      expect(repo.listCallCount, 1);
      expect(deposits, hasLength(2));
      expect(deposits[0].id, 'dep-matched');
      expect(
        sink.entries.map((e) => e.message),
        contains('Deposits listed'),
      );
    });

    test('surfaces repository failures while keeping payer names out of logs',
        () async {
      final repo = FakeFinancialDepositRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'deposits down',
          code: 'PLT999',
        );
      final sink = RecordingSink();
      final service = build(repo: repo, logger: makeLogger(sink));

      await expectLater(
        service.listDeposits(),
        throwsA(isA<ApiException>()),
      );
      expect(sink.entries, isNotEmpty);
      expect(sink.entries.join('\n'), isNot(contains('John Doe')));
    });
  });
}