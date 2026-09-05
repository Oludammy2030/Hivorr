import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';
import 'package:hivorr/data/repositories/conversion_repository_impl.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';

import '../../../support/fakes/fake_conversion_rate_source.dart';
import '../../../support/fakes/finance/fake_conversion_remote_data_source.dart';
import '../../../support/fakes/finance/fake_financial_repository.dart';

/// Unit coverage for [ConversionRepositoryImpl] (EP-02-15 §5.4): the rate the
/// repository hands to `financial_convert_currency` originates **exclusively**
/// from the injected [ConversionRateSource] seam (DoD SV-01), the preview is
/// zero-RPC, and every pair/amount/rate invariant is validated before any RPC
/// attempt.
void main() {
  ConversionRepositoryImpl build({
    ConversionRateSource? rateSource,
    FakeConversionRemoteDataSource? remote,
    FakeFinancialRepository? financial,
    double fee = 0,
  }) =>
      ConversionRepositoryImpl(
        remote: remote ?? FakeConversionRemoteDataSource(),
        rateSource: rateSource ?? FakeConversionRateSource(),
        financialRepository: financial ?? FakeFinancialRepository(),
        fee: fee,
      );

  const ApiException insufficientBalance = ApiException(
    kind: ApiExceptionKind.conflict,
    message: 'Insufficient source balance.',
    code: 'PLT006',
  );

  group('getRate', () {
    test('delegates to the seam with the requested directed pair', () async {
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(rateSource: rateSource);

      final double rate = await repo.getRate(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
      );

      expect(rate, 0.0007);
      expect(rateSource.rateForCallCount, 1);
      expect(rateSource.lastFromCurrency, 'NGN');
      expect(rateSource.lastToCurrency, 'USD');
    });

    test('validates the pair before delegating (unsupported currency, PLT003)',
        () async {
      final rateSource = FakeConversionRateSource();
      final repo = build(rateSource: rateSource);

      await expectLater(
        repo.getRate(fromCurrency: 'XYZ', toCurrency: 'USD'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind',
                  ApiExceptionKind.validation)
              .having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(rateSource.rateForCallCount, 0);
    });

    test('rejects a self-pair as validation error before any seam call',
        () async {
      final rateSource = FakeConversionRateSource();
      final repo = build(rateSource: rateSource);

      await expectLater(
        repo.getRate(fromCurrency: 'NGN', toCurrency: 'NGN'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.validation,
          ),
        ),
      );
      expect(rateSource.rateForCallCount, 0);
    });

    test('fails closed when the seam has no configured rate', () async {
      const ConversionRateUnavailableException e =
          ConversionRateUnavailableException();
      final rateSource = FakeConversionRateSource()
        ..nextError = e;
      final repo = build(rateSource: rateSource);

      await expectLater(
        repo.getRate(fromCurrency: 'NGN', toCurrency: 'USD'),
        throwsA(isA<ConversionRateUnavailableException>()),
      );
    });

    test('performs no RPC whatsoever', () async {
      final remote = FakeConversionRemoteDataSource();
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(remote: remote, rateSource: rateSource);

      await repo.getRate(fromCurrency: 'NGN', toCurrency: 'USD');

      expect(remote.convertCallCount, 0);
      expect(remote.historyCallCount, 0);
    });
  });

  group('previewConversion', () {
    test('computes the local estimate against the trusted rate with zero RPCs',
        () async {
      final remote = FakeConversionRemoteDataSource();
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(remote: remote, rateSource: rateSource);

      final ConversionPreview preview = await repo.previewConversion(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
      );

      expect(preview.fromCurrency, 'NGN');
      expect(preview.toCurrency, 'USD');
      expect(preview.fromAmount, 50000);
      expect(preview.grossAmount, closeTo(35, 1e-9));
      expect(preview.fee, 0);
      expect(preview.toAmount, closeTo(35, 1e-9));
      expect(preview.exchangeRate, 0.0007);
      expect(preview.isActionable, isTrue);
      expect(remote.convertCallCount, 0);
      expect(remote.historyCallCount, 0);
    });

    test('applies the injected fee to the net (toAmount = gross - fee)',
        () async {
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(rateSource: rateSource, fee: 5);

      final ConversionPreview preview = await repo.previewConversion(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
      );

      expect(preview.grossAmount, closeTo(35, 1e-9));
      expect(preview.fee, 5);
      expect(preview.toAmount, closeTo(30, 1e-9));
    });

    test('rejects a non-positive or non-finite amount (PLT003)', () async {
      final remote = FakeConversionRemoteDataSource();
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(remote: remote, rateSource: rateSource);

      await expectLater(
        repo.previewConversion(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 0,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      await expectLater(
        repo.previewConversion(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: double.infinity,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.convertCallCount, 0);
    });

    test('fails closed when the seam returns a non-positive rate', () async {
      final repo = build(
        rateSource: _ZeroRateSource(),
      );

      await expectLater(
        repo.previewConversion(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 100,
        ),
        throwsA(isA<ConversionRateUnavailableException>()),
      );
    });
  });

  group('executeConversion', () {
    test('hands the trusted seam rate to the remote and returns the mapped '
        'conversion', () async {
      final remote = FakeConversionRemoteDataSource();
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final financial = FakeFinancialRepository();
      final repo = build(
        remote: remote,
        rateSource: rateSource,
        financial: financial,
      );

      final CurrencyConversion conversion = await repo.executeConversion(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
      );

      expect(conversion.id, 'conversion-rpc-1');
      expect(conversion.fromCurrency, 'NGN');
      expect(conversion.toCurrency, 'USD');
      expect(conversion.status, 'completed');
      expect(remote.convertCallCount, 1);
      expect(remote.lastFromCurrency, 'NGN');
      expect(remote.lastToCurrency, 'USD');
      expect(remote.lastAmount, 50000);
      // The rate the remote received is the seam rate — never user input.
      expect(remote.lastRate, 0.0007);
      expect(conversion.toAmount, closeTo(35, 1e-9));
      // Best-effort balance refresh ran via the financial repository.
      expect(financial.statusCallCount, 1);
    });

    test('surfaces PLT006 insufficient balance as a conflict ApiException',
        () async {
      final remote = FakeConversionRemoteDataSource()
        ..nextError = insufficientBalance;
      final financial = FakeFinancialRepository();
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(
        remote: remote,
        rateSource: rateSource,
        financial: financial,
      );

      await expectLater(
        repo.executeConversion(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 50000,
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind',
                  ApiExceptionKind.conflict)
              .having((ApiException e) => e.code, 'code', 'PLT006'),
        ),
      );
      // The failed RPC must not trigger a balance refresh.
      expect(financial.statusCallCount, 0);
    });

    test('a balance-refresh failure never fails an already-committed '
        'conversion', () async {
      final financial = FakeFinancialRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'refresh down',
          code: 'PLT999',
        );
      final rateSource = FakeConversionRateSource()
        ..setRate('NGN', 'USD', 0.0007);
      final repo = build(
        rateSource: rateSource,
        financial: financial,
      );

      final CurrencyConversion conversion = await repo.executeConversion(
        fromCurrency: 'NGN',
        toCurrency: 'USD',
        amount: 50000,
      );

      expect(conversion.status, 'completed');
      expect(financial.statusCallCount, 1);
    });

    test('fails closed before any RPC when the seam rate is unavailable',
        () async {
      final remote = FakeConversionRemoteDataSource();
      final repo = build(remote: remote, rateSource: _ZeroRateSource());

      await expectLater(
        repo.executeConversion(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: 50000,
        ),
        throwsA(isA<ConversionRateUnavailableException>()),
      );
      expect(remote.convertCallCount, 0);
    });

    test('validates pair and amount before any seam or RPC call', () async {
      final remote = FakeConversionRemoteDataSource();
      final rateSource = FakeConversionRateSource();
      final repo = build(remote: remote, rateSource: rateSource);

      await expectLater(
        repo.executeConversion(
          fromCurrency: 'NGN',
          toCurrency: 'NGN',
          amount: 100,
        ),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repo.executeConversion(
          fromCurrency: 'NGN',
          toCurrency: 'USD',
          amount: -1,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.convertCallCount, 0);
      expect(rateSource.rateForCallCount, 0);
    });
  });

  group('getHistory', () {
    test('maps remote DTOs to entities in order', () async {
      final remote = FakeConversionRemoteDataSource(
        history: <CurrencyConversionDto>[
          seedConversionDto(id: 'c-1'),
          seedConversionDto(
            id: 'c-2',
            fromCurrency: 'USD',
            toCurrency: 'GHS',
          ),
        ],
      );
      final repo = build(remote: remote);

      final List<CurrencyConversion> history = await repo.getHistory();

      expect(history, hasLength(2));
      expect(history.first.id, 'c-1');
      expect(history.first.isCompleted, isTrue);
      expect(history.last.fromCurrency, 'USD');
      expect(history.last.toCurrency, 'GHS');
    });

    test('returns an empty list when the remote has no rows', () async {
      final repo = build(remote: FakeConversionRemoteDataSource());

      final List<CurrencyConversion> history = await repo.getHistory();

      expect(history, isEmpty);
    });

    test('surfaces remote history failures as ApiException', () async {
      final remote = FakeConversionRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'history down',
          code: 'PLT999',
        );
      final repo = build(remote: remote);

      await expectLater(
        repo.getHistory(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });
  });
}

/// Seam whose rateFor always returns a non-positive value — used to prove the
/// repository fails closed instead of trusting a degenerate rate.
class _ZeroRateSource implements ConversionRateSource {
  @override
  Future<double> rateFor({
    required String fromCurrency,
    required String toCurrency,
  }) async => 0;
}