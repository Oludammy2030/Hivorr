import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_conversion_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_remote_data_source.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/data/repositories/conversion_repository_impl.dart';
import 'package:hivorr/data/repositories/financial_repository_impl.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

/// Currency-conversion fake-E2E flow (EP-02-15): the REAL
/// `SupabaseConversionRemoteDataSource` + [ConfigConversionRateSource] +
/// [ConversionRepositoryImpl] + [ConversionService] + [ConversionProvider] run
/// the whole rate → estimate → execute → history lifecycle against a scripted
/// Supabase transport with **closure-state server semantics** (the simulated
/// `financial_convert_currency` commits `to_amount = p_amount * p_rate` and
/// appends the row to the history read model). Only the RPC transport is
/// scripted — no datasource/repository/service logic is faked. The rate handed
/// to the RPC is asserted to be exactly the seam rate (rate-integrity,
/// DoD SV-01).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const WalletConversionPairsConfig pairsConfig = WalletConversionPairsConfig(
    enabled: true,
    baseCrossRates: <String, double>{
      'NGN|USD': 0.0007,
    },
  );

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  // ---- Scripted "server" state -------------------------------------------
  int convertRpcCount = 0;
  double? lastRateSeen;
  final List<Map<String, dynamic>> historyRows = <Map<String, dynamic>>[];

  final SupabaseConversionRemoteDataSource conversionDataSource =
      SupabaseConversionRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
        'financial_convert_currency': (Map<String, dynamic> body) {
          convertRpcCount++;
          final double rate = (body['p_rate'] as num).toDouble();
          lastRateSeen = rate;
          final double fromAmount = (body['p_amount'] as num).toDouble();
          final double toAmount = fromAmount * rate;
          final String conversionId = 'conversion-rpc-$convertRpcCount';
          // Server-authoritative commit: append the read-model row.
          historyRows.add(<String, dynamic>{
            'conversion_id': conversionId,
            'entity_id': 'u1',
            'from_currency': body['p_from_currency'],
            'to_currency': body['p_to_currency'],
            'from_amount': fromAmount,
            'to_amount': toAmount,
            'exchange_rate': rate,
            'fee': 0,
            'status': 'completed',
            'created_at': '2026-01-01T00:00:00.000Z',
            'completed_at': '2026-01-01T00:00:00.000Z',
          });
          return ok(<String, dynamic>{
            'conversion_id': conversionId,
            'from_amount': fromAmount,
            'to_amount': toAmount,
            'rate': rate,
          });
        },
      },
      queryResults: <String, List<Map<String, dynamic>>>{
        'financial_conversions': historyRows,
      },
    ),
    exceptionMapper: const ApiExceptionMapper(),
  );

  final SupabaseFinancialRemoteDataSource financialDataSource =
      SupabaseFinancialRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
        'financial_status_get': (_) => ok(<String, dynamic>{
            'default_currency': 'NGN',
            'profile_status': 'active',
            'balances': <dynamic>[
              <String, dynamic>{
                'currency_code': 'NGN',
                'available_balance': 0,
                'held_balance': 0,
                'pending_balance': 0,
                'total_deposited': 50000,
                'total_withdrawn': 50000,
              },
            ],
            'active_escrow_count': 0,
            'cashout_limit': 100000,
          }),
      },
    ),
    exceptionMapper: const ApiExceptionMapper(),
  );

  final FinancialRepositoryImpl financialRepository =
      FinancialRepositoryImpl(remote: financialDataSource);

  final ConversionRepositoryImpl conversionRepository =
      ConversionRepositoryImpl(
    remote: conversionDataSource,
    rateSource: const ConfigConversionRateSource(pairsConfig),
    financialRepository: financialRepository,
  );

  final ConversionService conversionService = ConversionService(
    repository: conversionRepository,
    pairsConfig: pairsConfig,
  );

  late ConversionProvider provider;

  setUp(() {
    provider = ConversionProvider(
      service: conversionService,
      financialService: FinancialService(repository: financialRepository),
    );
  });

  tearDown(() {
    provider.dispose();
  });

  test('rate → estimate → execute → history fake-E2E with server semantics',
      () async {
    // 1. History is empty on the server initially.
    await provider.loadHistory();
    expect(provider.history, isEmpty);

    // 2. Select the directed pair and fetch the trusted rate from the seam.
    provider.setSource('NGN');
    provider.setDestination('USD');
    await provider.loadRate();
    expect(provider.rate, 0.0007);
    expect(provider.isRateUnavailable, isFalse);

    // 3. Local zero-RPC estimate against the trusted rate.
    provider.setAmount(50000);
    await provider.refreshPreview();
    expect(provider.preview, isNotNull);
    expect(provider.preview!.grossAmount, closeTo(35, 1e-9));
    expect(provider.preview!.exchangeRate, 0.0007);
    expect(convertRpcCount, 0); // estimates never touch the RPC.

    // 4. Execute through the real RPC + repository.
    await provider.execute();
    expect(convertRpcCount, 1);
    expect(lastRateSeen, 0.0007); // exact seam rate handed to the RPC.
    expect(provider.lastConversion, isNotNull);
    expect(provider.lastConversion!.id, 'conversion-rpc-1');
    expect(provider.lastConversion!.status, 'completed');
    expect(provider.lastConversion!.fromAmount, 50000);
    // The authoritative toAmount comes from the server's formula, not the
    // client estimate (DoD SV-07).
    expect(provider.lastConversion!.toAmount, closeTo(35, 1e-9));
    expect(provider.lastConversion!.fee, 0);

    // 5. The scripted server committed the row; re-read it through the real
    //    REST history seam.
    await provider.loadHistory();
    expect(provider.history, hasLength(1));
    final CurrencyConversion row = provider.history.single;
    expect(row.id, 'conversion-rpc-1');
    expect(row.fromCurrency, 'NGN');
    expect(row.toCurrency, 'USD');
    expect(row.fromAmount, 50000);
    expect(row.toAmount, closeTo(35, 1e-9));
    expect(row.status, 'completed');
  });
}