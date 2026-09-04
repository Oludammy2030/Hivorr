import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_remote_data_source.dart';
import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

void main() {
  SupabaseFinancialRemoteDataSource build([
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ]) =>
      SupabaseFinancialRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(rpcHandlers: rpcHandlers),
        exceptionMapper: const ApiExceptionMapper(),
      );

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  Map<String, dynamic> profileData({
    String status = 'active',
    String defaultCurrency = 'NGN',
  }) =>
      <String, dynamic>{
        'profile': <String, dynamic>{
          'id': 'p1',
          'entity_id': 'u1',
          'status': status,
          'default_currency': defaultCurrency,
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        'currency_accounts': <dynamic>[],
      };

  Map<String, dynamic> balanceData({
    String currencyCode = 'NGN',
    double available = 50000,
    double held = 0,
    double pending = 0,
    double totalDeposited = 50000,
    double totalWithdrawn = 0,
  }) =>
      <String, dynamic>{
        'currency_code': currencyCode,
        'available_balance': available,
        'held_balance': held,
        'pending_balance': pending,
        'total_deposited': totalDeposited,
        'total_withdrawn': totalWithdrawn,
      };

  Map<String, dynamic> statusData({
    String defaultCurrency = 'NGN',
    double cashoutLimit = 100000,
  }) =>
      <String, dynamic>{
        'default_currency': defaultCurrency,
        'profile_status': 'active',
        'balances': <dynamic>[
          balanceData(currencyCode: 'NGN'),
        ],
        'active_escrow_count': 0,
        'cashout_limit': cashoutLimit,
      };

  group('SupabaseFinancialRemoteDataSource.getProfile', () {
    test('calls financial_profile_get and maps profile', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_profile_get': (Map<String, dynamic> body) {
          seenFn = 'financial_profile_get';
          seenParams = body;
          return ok(profileData());
        },
      });

      final FinancialProfileDto? dto = await source.getProfile();

      expect(seenFn, 'financial_profile_get');
      expect(seenParams, isEmpty);
      expect(dto, isNotNull);
      expect(dto!.id, 'p1');
      expect(dto.defaultCurrency, 'NGN');
    });

    test('returns null when no profile row exists', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_profile_get': (_) => ok(<String, dynamic>{
              'profile': null,
              'currency_accounts': <dynamic>[],
            }),
      });

      final FinancialProfileDto? dto = await source.getProfile();

      expect(dto, isNull);
    });
  });

  group('SupabaseFinancialRemoteDataSource.getBalance', () {
    test('calls financial_balance_get with currency code', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_balance_get': (Map<String, dynamic> body) {
          seenFn = 'financial_balance_get';
          seenParams = body;
          return ok(balanceData());
        },
      });

      final BalanceDto dto = await source.getBalance('NGN');

      expect(seenFn, 'financial_balance_get');
      expect(seenParams!['p_currency_code'], 'NGN');
      expect(dto.currencyCode, 'NGN');
      expect(dto.availableBalance, 50000);
    });

    test('defaults zero balances when no row exists', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_balance_get': (_) => ok(<String, dynamic>{
              'currency_code': 'NGN',
              'available_balance': 0,
              'held_balance': 0,
              'pending_balance': 0,
              'total_deposited': 0,
              'total_withdrawn': 0,
            }),
      });

      final BalanceDto dto = await source.getBalance('NGN');

      expect(dto.availableBalance, 0);
      expect(dto.heldBalance, 0);
      expect(dto.pendingBalance, 0);
    });
  });

  group('SupabaseFinancialRemoteDataSource.getStatus', () {
    test('calls financial_status_get and maps aggregate', () async {
      String? seenFn;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_status_get': (Map<String, dynamic> body) {
          seenFn = 'financial_status_get';
          return ok(statusData(cashoutLimit: 250000));
        },
      });

      final FinancialStatusDto dto = await source.getStatus();

      expect(seenFn, 'financial_status_get');
      expect(dto.cashoutLimit, 250000);
      expect(dto.balances, hasLength(1));
      expect(dto.activeEscrowCount, 0);
    });
  });

  group('SupabaseFinancialRemoteDataSource.createProfile', () {
    test('calls financial_profile_create then re-reads profile', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_profile_create': (Map<String, dynamic> body) {
          seenFn = 'financial_profile_create';
          seenParams = body;
          return ok(<String, dynamic>{
            'profile_id': 'p1',
            'default_currency': 'NGN',
            'balance_id': 'b1',
          });
        },
        'financial_profile_get': (_) => ok(profileData()),
      });

      final FinancialProfileDto dto =
          await source.createProfile(defaultCurrency: 'NGN');

      expect(seenFn, 'financial_profile_create');
      expect(seenParams!['p_default_currency'], 'NGN');
      expect(dto.defaultCurrency, 'NGN');
    });
  });

  group('envelope error mapping', () {
    test('maps PLT005 conflict to conflict kind', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_profile_create': (_) => <String, dynamic>{
              'code': 'PLT005',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.createProfile(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)
            .having((ApiException e) => e.code, 'code', 'PLT005')),
      );
    });

    test('maps PLT004 to notFound', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_balance_get': (_) => <String, dynamic>{
              'code': 'PLT004',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.getBalance('XYZ'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.notFound)),
      );
    });

    test('throws server when data is malformed (not an object)', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_status_get': (_) => <String, dynamic>{
              'success': true,
              'code': 'PLT000',
              'data': <dynamic>[1, 2],
            },
      });

      expect(
        () => source.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
      );
    });

    test('maps 42501 SQL error to forbidden', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_status_get': (_) => <String, dynamic>{
              'code': '42501',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.forbidden)),
      );
    });
  });
}
