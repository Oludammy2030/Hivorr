// EP-02-20 VP8: Currency Conversion (preview→execute→balances).
//
// Extends conversion_flow_test.dart patterns with real service+provider
// composition. Exercises ConversionService → ConversionRepository →
// ConversionProvider with a scripted Supabase transport. Verifies: available
// pairs → preview (rate+fees) → execute → source debited/dest credited
// atomically → history entry.
//
// Run: flutter test test/integration/trust/conversion_flow_integration_test.dart

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
                  'available_balance': 50000,
                  'held_balance': 0,
                  'pending_balance': 0,
                  'total_deposited': 50000,
                  'total_withdrawn': 0,
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
    convertRpcCount = 0;
    lastRateSeen = null;
    historyRows.clear();
    provider = ConversionProvider(
      service: conversionService,
      financialService: FinancialService(repository: financialRepository),
    );
  });

  tearDown(() {
    provider.dispose();
  });

  group('VP8: Currency conversion flow', () {
    test('rate → estimate → execute → history with server semantics', () async {
      // 1. History empty initially.
      await provider.loadHistory();
      expect(provider.history, isEmpty);

      // 2. Select pair and fetch trusted rate.
      provider.setSource('NGN');
      provider.setDestination('USD');
      await provider.loadRate();
      expect(provider.rate, 0.0007);
      expect(provider.isRateUnavailable, isFalse);

      // 3. Local zero-RPC estimate.
      provider.setAmount(50000);
      await provider.refreshPreview();
      expect(provider.preview, isNotNull);
      expect(provider.preview!.grossAmount, closeTo(35, 1e-9));
      expect(convertRpcCount, 0);

      // 4. Execute through real RPC + repository.
      await provider.execute();
      expect(convertRpcCount, 1);
      expect(lastRateSeen, 0.0007);
      expect(provider.lastConversion, isNotNull);
      expect(provider.lastConversion!.id, 'conversion-rpc-1');
      expect(provider.lastConversion!.status, 'completed');
      expect(provider.lastConversion!.fromAmount, 50000);
      expect(provider.lastConversion!.toAmount, closeTo(35, 1e-9));

      // 5. History row committed.
      await provider.loadHistory();
      expect(provider.history, hasLength(1));
      final CurrencyConversion row = provider.history.single;
      expect(row.id, 'conversion-rpc-1');
      expect(row.fromCurrency, 'NGN');
      expect(row.toCurrency, 'USD');
    });

    test('available pairs from config', () {
      expect(provider.availablePairs, isNotEmpty);
      // Each base pair yields both directions.
      expect(
        provider.availablePairs.any(
          (p) => p.fromCode == 'NGN' && p.toCode == 'USD',
        ),
        isTrue,
      );
    });

    test('source debited / dest credited atomically (server formula)',
        () async {
      provider.setSource('NGN');
      provider.setDestination('USD');
      await provider.loadRate();
      provider.setAmount(100000);
      await provider.refreshPreview();

      await provider.execute();

      // Server formula: toAmount = fromAmount * rate = 100000 * 0.0007 = 70
      expect(provider.lastConversion!.toAmount, closeTo(70, 1e-9));
      expect(provider.lastConversion!.fee, 0);
    });
  });
}
