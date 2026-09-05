import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/data/repositories/conversion_repository_impl.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

import '../../../support/fakes/fake_conversion_rate_source.dart';
import '../../../support/fakes/finance/fake_conversion_remote_data_source.dart';
import '../../../support/fakes/finance/fake_financial_repository.dart';

/// Unit coverage for TT-06: after `executeConversion` the real repository and
/// provider re-read `financial_status_get` through the injected
/// [FinancialRepository] so the balances map reflects the server-authoritative
/// post-conversion state (DoD FV-43/DV-07) — never a local optimistic
/// decrement. The refresh must also be best-effort: a read-model failure never
/// fails an already-committed conversion.
void main() {
  ConversionRepositoryImpl buildRepo({
    required FakeConversionRemoteDataSource remote,
    required FakeConversionRateSource rateSource,
    required FakeFinancialRepository financial,
  }) =>
      ConversionRepositoryImpl(
        remote: remote,
        rateSource: rateSource,
        financialRepository: financial,
      );

  ConversionProvider buildProvider(
    ConversionRepositoryImpl repo,
    FakeFinancialRepository financial,
  ) =>
      ConversionProvider(
        service: ConversionService(
          repository: repo,
          pairsConfig: const WalletConversionPairsConfig(
            enabled: true,
            baseCrossRates: <String, double>{
              'NGN|USD': 0.0007,
            },
          ),
        ),
        financialService: FinancialService(repository: financial),
      );

  FakeConversionRemoteDataSource seededRemote() =>
      FakeConversionRemoteDataSource()
        ..setConversion(
          seedConversionDto(id: 'conversion-bal', toAmount: 35),
        );

  FakeFinancialRepository seededFinancial({bool postRefreshError = false}) {
    final financial = FakeFinancialRepository(
      status: seedStatusEntity(
        balances: <Balance>[
          seedBalanceEntity(currencyCode: 'NGN', available: 0),
          seedBalanceEntity(currencyCode: 'USD', available: 35),
        ],
      ),
    );
    financial.nextError = postRefreshError
        ? const ApiException(
            kind: ApiExceptionKind.server,
            message: 'status read down',
          )
        : null;
    return financial;
  }

  test('execute re-reads financial_status_get after the committed conversion',
      () async {
    final remote = seededRemote();
    final rateSource = FakeConversionRateSource()
      ..setRate('NGN', 'USD', 0.0007);
    final financial = seededFinancial();
    final repo = buildRepo(
      remote: remote,
      rateSource: rateSource,
      financial: financial,
    );

    await repo.executeConversion(
      fromCurrency: 'NGN',
      toCurrency: 'USD',
      amount: 50000,
    );

    expect(financial.statusCallCount, 1);
    expect(remote.lastRate, 0.0007);
  });

  test('the refresh reflects server-authoritative balances (no optimistic '
      'decrement)', () async {
    final financial = seededFinancial();
    final provider = buildProvider(
      buildRepo(
        remote: seededRemote(),
        rateSource: FakeConversionRateSource()..setRate('NGN', 'USD', 0.0007),
        financial: financial,
      ),
      financial,
    );
    addTearDown(provider.dispose);

    provider
      ..setSource('NGN')
      ..setDestination('USD')
      ..setAmount(50000);
    await provider.execute();

    expect(provider.lastConversion?.status, 'completed');
    expect(financial.statusCallCount, greaterThanOrEqualTo(1));
    expect(
      (await financial.getStatus())
          .balances
          .firstWhere((Balance b) => b.currencyCode == 'NGN')
          .availableBalance,
      0,
    );
    expect(
      (await financial.getStatus())
          .balances
          .firstWhere((Balance b) => b.currencyCode == 'USD')
          .availableBalance,
      35,
    );
  });

  test('a refresh failure never fails an already-committed conversion', () async {
    final financial = seededFinancial(postRefreshError: true);
    final remote = seededRemote();
    final repo = buildRepo(
      remote: remote,
      rateSource: FakeConversionRateSource()..setRate('NGN', 'USD', 0.0007),
      financial: financial,
    );

    final conversion = await repo.executeConversion(
      fromCurrency: 'NGN',
      toCurrency: 'USD',
      amount: 50000,
    );

    expect(conversion.id, 'conversion-bal');
    expect(conversion.status, 'completed');
    expect(remote.convertCallCount, 1);
  });

  test('a failed conversion triggers no balance refresh', () async {
    final remote = seededRemote()
      ..nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Insufficient source balance.',
        code: 'PLT006',
      );
    final financial = seededFinancial();
    final repo = buildRepo(
      remote: remote,
      rateSource: FakeConversionRateSource()..setRate('NGN', 'USD', 0.0007),
      financial: financial,
    );

    await expectLater(
      repo.executeConversion(fromCurrency: 'NGN', toCurrency: 'USD', amount: 50000),
      throwsA(
        isA<ApiException>()
            .having((ApiException e) => e.code, 'code', 'PLT006'),
      ),
    );
    expect(financial.statusCallCount, 0);
  });
}