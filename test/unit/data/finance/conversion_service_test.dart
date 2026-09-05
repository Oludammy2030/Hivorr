import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/config/wallet/wallet_conversion_rates_seed.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/systems/finance/models/conversion_pair.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/finance/fake_conversion_repository.dart';

/// Unit coverage for [ConversionService] (EP-02-15 §5.5): the facade exposes
/// flag-gated pairs from the single rate authority, delegates every data
/// operation to the repository, and renders locale-aware preview/rate copy
/// (DoD FV-24/FV-25). Logging/tracing branches are exercised with a
/// [RecordingSink] logger and a disabled [PerformanceTracer].
void main() {
  ConversionService build({
    FakeConversionRepository? repo,
    WalletConversionPairsConfig? pairsConfig,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
  }) =>
      ConversionService(
        repository: repo ?? FakeConversionRepository(),
        pairsConfig:
            pairsConfig ??
            const WalletConversionPairsConfig(
              enabled: true,
              baseCrossRates: <String, double>{
                'NGN|USD': 0.0007,
              },
            ),
        logger: logger,
        tracer: tracer,
      );

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test.conversion',
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

  group('availablePairs', () {
    test('yields the directed pairs from the rate authority when enabled',
        () {
      final service = build(
        pairsConfig: const WalletConversionPairsConfig(
          enabled: true,
          baseCrossRates: <String, double>{
            'NGN|USD': 0.0007,
          },
        ),
      );

      expect(service.availablePairs, hasLength(2));
      expect(
        service.availablePairs.map((ConversionPair p) => '${p.fromCode}|${p.toCode}'),
        containsAll(<String>['NGN|USD', 'USD|NGN']),
      );
    });

    test('exposes no pairs while conversion is flag-gated off', () {
      final service = build(pairsConfig: const WalletConversionPairsConfig());
      expect(service.availablePairs, isEmpty);
    });

    test('seeded authority exposes exactly 12 directed pairs '
        '(6 ordered + 6 inverses)', () {
      final service = build(
        pairsConfig: const WalletConversionPairsConfig(
          enabled: true,
          baseCrossRates: WalletConversionRatesSeed.baseCrossRates,
        ),
      );

      expect(service.availablePairs, hasLength(12));
      expect(
        service.availablePairs
            .map((ConversionPair p) => '${p.fromCode}|${p.toCode}')
            .toSet(),
        <String>{
          'NGN|USD',
          'USD|NGN',
          'GHS|NGN',
          'NGN|GHS',
          'NGN|GBP',
          'GBP|NGN',
          'GHS|USD',
          'USD|GHS',
          'GHS|GBP',
          'GBP|GHS',
          'USD|GBP',
          'GBP|USD',
        },
      );
    });
  });

  group('getRate', () {
    test('delegates to the repository with the directed pair', () async {
      final repo = FakeConversionRepository()
        ..setRate('NGN', 'USD', 0.0007);
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      final double rate = await service.getRate(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
      );

      expect(rate, 0.0007);
      expect(repo.getRateCallCount, 1);
    });

    test('surfaces repository failures and logs the error', () async {
      final repo = FakeConversionRepository()
        ..setRate('NGN', 'USD', 0.0007)
        ..nextError = const ApiException(
          kind: ApiExceptionKind.unknown,
          message: 'rate down',
        );
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      await expectLater(
        service.getRate(fromCurrency: 'NGN', toCurrency: 'USD'),
        throwsException,
      );
      expect(sink.entries, isNotEmpty);
    });
  });

  group('previewConversion', () {
    test('delegates and returns the local estimate', () async {
      final repo = FakeConversionRepository()
        ..setRate('NGN', 'USD', 0.0007);
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      final ConversionPreview preview = await service.previewConversion(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
      );

      expect(preview.grossAmount, closeTo(35, 1e-9));
      expect(preview.fromAmount, 50000);
      expect(repo.previewCallCount, 1);
      expect(
        sink.entries.any((e) => e.message.contains('preview')),
        isTrue,
      );
    });
  });

  group('executeConversion', () {
    test('delegates to the repository and returns the conversion', () async {
      final repo = FakeConversionRepository()
        ..setRate('NGN', 'USD', 0.0007)
        ..setConversion(
          seedConversionEntity(id: 'conversion-x', toAmount: 35),
        );
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      final CurrencyConversion conversion = await service.executeConversion(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
      );

      expect(conversion.id, 'conversion-x');
      expect(conversion.status, 'completed');
      expect(repo.executeCallCount, 1);
      expect(
        sink.entries.any((e) => e.message.contains('executed')),
        isTrue,
      );
    });
  });

  group('getHistory', () {
    test('delegates to the repository and returns mapped rows', () async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[
          seedConversionEntity(id: 'c-1'),
        ],
      );
      final sink = RecordingSink();
      final service = build(
        repo: repo,
        logger: makeLogger(sink),
        tracer: disabledTracer(),
      );

      final List<CurrencyConversion> history = await service.getHistory();

      expect(history, hasLength(1));
      expect(history.single.id, 'c-1');
      expect(repo.historyCallCount, 1);
      expect(
        sink.entries.any((e) => e.message.contains('history')),
        isTrue,
      );
    });
  });

  group('formatting (DoD FV-24/FV-25)', () {
    test('preview renders with currency symbols and thousands separators', () {
      final service = build();
      const ConversionPreview preview = ConversionPreview(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        fromAmount: 50000,
        grossAmount: 35,
        fee: 0,
        toAmount: 35,
        exchangeRate: 0.0007,
      );

      expect(service.formatPreview(preview), contains('\u20A650,000.00'));
      expect(service.formatPreview(preview), contains('\u2192'));
      expect(service.formatPreview(preview), contains('\$35.00'));
    });

    test('rate copy keeps significant decimals for sub-unit rates', () {
      final service = build();
      expect(
        service.formatRate(0.0007,
            fromCurrency: 'NGN', toCurrency: 'USD'),
        '1 NGN = 0.0007 USD',
      );
    });

    test('rate copy uses two decimals for whole rates', () {
      final service = build();
      expect(
        service.formatRate(1111.1111111111111,
            fromCurrency: 'GHS', toCurrency: 'NGN'),
        '1 GHS = 1111.11 NGN',
      );
    });
  });
}