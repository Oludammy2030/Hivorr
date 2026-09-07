import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/finance/fake_financial_payout_repository.dart';

void main() {
  FinancialPayoutService build({
    FakeFinancialPayoutRepository? repo,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
  }) =>
      FinancialPayoutService(
        repository: repo ?? FakeFinancialPayoutRepository(),
        logger: logger,
        tracer: tracer,
      );

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test.payout',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.info),
        PiiRedactor(),
      );

  PerformanceTracer disabledTracer() => PerformanceTracer(
        MonitoringConfig.fromSource(MapEnvironmentValueSource(
          <String, String>{
            'HIVORR_MONITORING_ENABLE_SENTRY': 'true',
            'HIVORR_MONITORING_SENTRY_DSN': 'https://x@y/1',
          },
        )),
        const FeatureFlags(
          enableVerboseLogging: false,
          enableOfflineSync: false,
          enableAnalyticsTracking: false,
          enableDynamicWorkspaceLoading: false,
          enablePayloadOptimization: false,
          enablePushNotifications: false,
        ),
      );

  group('bindAccount', () {
    test('delegates and logs a masked account number, never the raw value',
        () async {
      final repo = FakeFinancialPayoutRepository();
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      final PayoutAccount account = await service.bindAccount(
        currencyCode: 'NGN',
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
      );

      expect(repo.bindCallCount, 1);
      expect(account.id, 'acc-0123456789');
      final List<String> messages = sink.entries.map((e) => e.message).toList();
      expect(messages, contains('Binding payout account'));
      expect(messages, contains('Payout account bound'));
      expect(messages.join('\n'), isNot(contains('0123456789')));
    });

    test('surfaces repository failures and logs the error', () async {
      const ApiException failure = ApiException(
        kind: ApiExceptionKind.server,
        message: 'bind down',
        code: 'PLT999',
      );
      final repo = FakeFinancialPayoutRepository()..nextError = failure;
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      await expectLater(
        service.bindAccount(
          currencyCode: 'NGN',
          bankName: 'B',
          accountNumber: '0123456789',
          accountName: 'N',
        ),
        throwsA(same(failure)),
      );
      expect(sink.entries, isNotEmpty);
    });
  });

  group('listPayoutAccounts', () {
    test('delegates and reports the mirror count', () async {
      final repo = FakeFinancialPayoutRepository(
        seed: <PayoutAccount>[
          FakeFinancialPayoutRepository.verified(),
          FakeFinancialPayoutRepository.unverified(),
        ],
      );
      final sink = RecordingSink();
      final service = build(repo: repo, logger: makeLogger(sink));

      final List<PayoutAccount> accounts = await service.listPayoutAccounts();

      expect(repo.listCallCount, 1);
      expect(accounts, hasLength(2));
    });
  });

  group('withdraw', () {
    test('delegates and returns the mapped result', () async {
      final repo = FakeFinancialPayoutRepository();
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      final result = await service.withdraw(
        payoutAccountId: 'acc-1',
        amount: 50000,
      );

      expect(repo.withdrawCallCount, 1);
      expect(result.payoutId, 'pay-1');
      expect(result.cashoutRemaining, 999999);
      expect(
        sink.entries.map((e) => e.message),
        contains('Withdrawal initiated'),
      );
    });

    test('surfaces PLT006 insufficient-balance failures unchanged', () async {
      const ApiException insufficient = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Insufficient balance.',
        code: 'PLT006',
      );
      final repo = FakeFinancialPayoutRepository()..nextError = insufficient;
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      await expectLater(
        service.withdraw(payoutAccountId: 'acc-1', amount: 50000),
        throwsA(same(insufficient)),
      );
      expect(sink.entries, isNotEmpty);
    });
  });
}