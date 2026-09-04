import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_remote_data_source.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/repositories/financial_repository_impl.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

/// Financial fake-E2E flow (TT-31): the REAL datasource + repository run the
/// whole no-profile → create → re-read → balance → status lifecycle against a
/// scripted Supabase transport. Only the transport (RPC handlers) is scripted;
/// no repository/datasource logic is faked.
void main() {
  /// Scripted "server": no profile initially, then profile is created.
  bool profileExists = false;
  String defaultCurrency = 'NGN';

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

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
                    'account_status': 'pending',
                    'receiving_account_number': null,
                    'receiving_bank_name': null,
                    'activated_at': null,
                  },
                ],
              }
            : null,
      };

  Map<String, dynamic> statusData() => <String, dynamic>{
        'default_currency': defaultCurrency,
        'profile_status': profileExists ? 'active' : 'closed',
        'balances': profileExists
            ? <dynamic>[
                <String, dynamic>{
                  'currency_code': defaultCurrency,
                  'available_balance': 0,
                  'held_balance': 0,
                  'pending_balance': 0,
                  'total_deposited': 0,
                  'total_withdrawn': 0,
                },
              ]
            : <dynamic>[],
        'active_escrow_count': 0,
        'cashout_limit': 100000,
      };

  final SupabaseFinancialRemoteDataSource dataSource =
      SupabaseFinancialRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
        'financial_profile_get': (_) => ok(profileData()),
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
        'financial_status_get': (_) => ok(statusData()),
        'financial_profile_create': (Map<String, dynamic> body) {
          profileExists = true;
          defaultCurrency = body['p_default_currency'] as String? ?? 'NGN';
          return ok(<String, dynamic>{
            'profile_id': 'p1',
            'default_currency': defaultCurrency,
            'balance_id': 'b1',
          });
        },
      },
    ),
    exceptionMapper: const ApiExceptionMapper(),
  );

  final FinancialRepositoryImpl repository =
      FinancialRepositoryImpl(remote: dataSource);

  group('Financial fake-E2E profile flow', () {
    test('no-profile → create → re-read → balance → status', () async {
      // 1. No profile initially.
      final FinancialProfile? initial = await repository.getProfile();
      expect(initial, isNull);

      // 2. Create profile with default NGN.
      final FinancialProfile created =
          await repository.createProfile(defaultCurrency: 'NGN');
      expect(created.status, 'active');
      expect(created.defaultCurrency, 'NGN');

      // 3. Re-read the profile and confirm.
      final FinancialProfile? reRead = await repository.getProfile();
      expect(reRead, isNotNull);
      expect(reRead!.defaultCurrency, 'NGN');
      expect(reRead.isActive, isTrue);

      // 4. Account attached (pending).
      final List<CurrencyAccount> accounts = await repository.getAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.currencyCode, 'NGN');
      expect(accounts.single.isPending, isTrue);

      // 5. Balance defaults to zero.
      final Balance? balance = await repository.getBalance('NGN');
      expect(balance, isNotNull);
      expect(balance!.availableBalance, 0);
      expect(balance.heldBalance, 0);
      expect(balance.pendingBalance, 0);

      // 6. Status aggregate.
      final FinancialStatus status = await repository.getStatus();
      expect(status.defaultCurrency, 'NGN');
      expect(status.balances, hasLength(1));
      expect(status.balances.first.availableBalance, 0);
      expect(status.activeEscrowCount, 0);
      expect(status.cashoutLimit, 100000);
    });
  });
}
