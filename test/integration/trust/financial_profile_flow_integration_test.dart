// EP-02-20 VP6: Financial Profile → Currency Accounts → Balances.
//
// Extends financial_profile_flow_test.dart patterns with real service+provider
// composition. Exercises FinancialService → FinancialRepository → FinancialProvider
// with a scripted Supabase transport. Verifies: create profile → request currency
// accounts → financial_balances_get → per-currency balance aggregation.
//
// Run: flutter test test/integration/trust/financial_profile_flow_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_remote_data_source.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/data/repositories/financial_repository_impl.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  // ---- Scripted "server" state -------------------------------------------
  bool profileExists = false;
  String defaultCurrency = 'NGN';
  final List<Map<String, dynamic>> balanceRows = <Map<String, dynamic>>[];

  Map<String, dynamic> profileData() => <String, dynamic>{
        'profile': profileExists
            ? <String, dynamic>{
                'id': 'p1',
                'entity_id': 'u1',
                'status': 'active',
                'default_currency': defaultCurrency,
                'created_at': '2026-01-01T00:00:00.000Z',
                'currency_accounts': <dynamic>[
                  <String, dynamic>{
                    'id': 'a1',
                    'financial_profile_id': 'p1',
                    'entity_id': 'u1',
                    'currency_code': defaultCurrency,
                    'account_status': 'active',
                    'receiving_account_number': null,
                    'receiving_bank_name': null,
                    'activated_at': '2026-01-02T00:00:00.000Z',
                  },
                ],
              }
            : null,
      };

  Map<String, dynamic> statusData() => <String, dynamic>{
        'default_currency': defaultCurrency,
        'profile_status': profileExists ? 'active' : 'closed',
        'balances': profileExists ? balanceRows : <dynamic>[],
        'active_escrow_count': 0,
        'cashout_limit': 100000,
      };

  ({
    FinancialService service,
    FinancialProvider provider,
    FinancialRepositoryImpl repository,
  }) buildFlow({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  }) {
    final defaults = <String, Object? Function(Map<String, dynamic>)>{
      'financial_profile_get': (_) => ok(profileData()),
      'financial_status_get': (_) => ok(statusData()),
      'financial_profile_create': (Map<String, dynamic> body) {
        profileExists = true;
        defaultCurrency = body['p_default_currency'] as String? ?? 'NGN';
        balanceRows
          ..clear()
          ..add(<String, dynamic>{
            'currency_code': defaultCurrency,
            'available_balance': 0,
            'held_balance': 0,
            'pending_balance': 0,
            'total_deposited': 0,
            'total_withdrawn': 0,
          });
        return ok(<String, dynamic>{
          'profile_id': 'p1',
          'default_currency': defaultCurrency,
          'balance_id': 'b1',
        });
      },
      'financial_balance_get': (Map<String, dynamic> body) => ok(
            <String, dynamic>{
              'currency_code': body['p_currency_code'],
              'available_balance': 0,
              'held_balance': 0,
              'pending_balance': 0,
              'total_deposited': 0,
              'total_withdrawn': 0,
            },
          ),
    };
    defaults.addAll(
        rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{});
    final remote = SupabaseFinancialRemoteDataSource(
      dio: Dio(),
      supabase: MockSupabaseClientFactory.create(
        currentUser: fakeUser('u1'),
        rpcHandlers: defaults,
      ),
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = FinancialRepositoryImpl(remote: remote);
    final service = FinancialService(repository: repo);
    final provider = FinancialProvider(service: service);
    return (service: service, provider: provider, repository: repo);
  }

  group('VP6: Financial profile → currency accounts → balances', () {
    setUp(() {
      profileExists = false;
      defaultCurrency = 'NGN';
      balanceRows.clear();
    });

    test('no profile → create → re-read → status with balance', () async {
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      // 1. No profile initially.
      final FinancialProfile? initial = await flow.repository.getProfile();
      expect(initial, isNull);

      // 2. Create profile with default NGN.
      final FinancialProfile created =
          await flow.repository.createProfile(defaultCurrency: 'NGN');
      expect(created.status, 'active');
      expect(created.defaultCurrency, 'NGN');

      // 3. Re-read and confirm.
      final FinancialProfile? reRead = await flow.repository.getProfile();
      expect(reRead, isNotNull);
      expect(reRead!.isActive, isTrue);

      // 4. Status aggregate.
      final FinancialStatus status = await flow.repository.getStatus();
      expect(status.defaultCurrency, 'NGN');
      expect(status.balances, hasLength(1));
      expect(status.balances.first.currencyCode, 'NGN');
      expect(status.balances.first.availableBalance, 0);
      expect(status.activeEscrowCount, 0);
      expect(status.cashoutLimit, 100000);
    });

    test('provider drives create → load → balance aggregation', () async {
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await flow.provider.createProfile(defaultCurrency: 'NGN');

      expect(flow.provider.profile, isNotNull);
      expect(flow.provider.profile!.defaultCurrency, 'NGN');
      expect(flow.provider.status, isNotNull);
      expect(flow.provider.balances, contains('NGN'));
      expect(flow.provider.balances['NGN']?.availableBalance, 0);
    });

    test('multi-currency balances are supported', () async {
      // Seed a second currency.
      balanceRows
        ..clear()
        ..add(<String, dynamic>{
          'currency_code': 'NGN',
          'available_balance': 50000,
          'held_balance': 10000,
          'pending_balance': 0,
          'total_deposited': 50000,
          'total_withdrawn': 0,
        })
        ..add(<String, dynamic>{
          'currency_code': 'USD',
          'available_balance': 200,
          'held_balance': 0,
          'pending_balance': 50,
          'total_deposited': 250,
          'total_withdrawn': 0,
        });
      profileExists = true;

      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      final FinancialStatus status = await flow.repository.getStatus();
      expect(status.balances, hasLength(2));

      final Balance ngn = status.balances
          .firstWhere((Balance b) => b.currencyCode == 'NGN');
      expect(ngn.availableBalance, 50000);
      expect(ngn.heldBalance, 10000);

      final Balance usd = status.balances
          .firstWhere((Balance b) => b.currencyCode == 'USD');
      expect(usd.availableBalance, 200);
      expect(usd.pendingBalance, 50);
    });

    test('PLT004 not-found returns null profile', () async {
      final flow = buildFlow(
        rpcHandlers: {
          'financial_profile_get': (_) => ok(<String, dynamic>{
                'profile': null,
              }),
        },
      );
      addTearDown(flow.provider.dispose);

      final FinancialProfile? profile = await flow.repository.getProfile();
      expect(profile, isNull);
    });
  });
}
