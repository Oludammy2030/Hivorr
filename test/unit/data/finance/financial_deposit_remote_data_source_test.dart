import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_deposit_remote_data_source.dart';
import 'package:hivorr/data/models/deposit_dto.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../support/factories/mock_supabase_client_factory.dart';
import '../../../support/fakes/fake_supabase.dart';

void main() {
  SupabaseFinancialDepositRemoteDataSource build(
    Map<String, List<Map<String, dynamic>>> queryResults, {
    User? currentUser,
  }) =>
      SupabaseFinancialDepositRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: currentUser,
          queryResults: queryResults,
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

  group('SupabaseFinancialDepositRemoteDataSource.listDeposits', () {
    test('maps financial_deposits rows to DepositDto newest-first', () async {
      final source = build(<String, List<Map<String, dynamic>>>{
        'financial_deposits': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'dep-1',
            'currency_code': 'NGN',
            'amount': 150000,
            'name_match_status': 'matched',
            'status': 'credited',
          },
          <String, dynamic>{
            'id': 'dep-2',
            'currency_code': 'USD',
            'amount': 500,
            'name_match_status': 'pending',
            'status': 'pending',
          },
        ],
      });

      final List<DepositDto> deposits = await source.listDeposits();

      expect(deposits, hasLength(2));
      expect(deposits[0].id, 'dep-1');
      expect(deposits[0].nameMatchStatus, 'matched');
      expect(deposits[1].nameMatchStatus, 'pending');
    });

    test('returns an empty list when no rows match', () async {
      final source = build(<String, List<Map<String, dynamic>>>{
        'financial_deposits': <Map<String, dynamic>>[],
      });

      expect(await source.listDeposits(), isEmpty);
    });

    test('filters by entity_id when signed in as a user', () async {
      final source = build(
        <String, List<Map<String, dynamic>>>{
          'financial_deposits': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'dep-1',
              'currency_code': 'NGN',
              'amount': 100,
              'name_match_status': 'unverified',
            },
          ],
        },
        currentUser: fakeUser('entity-42'),
      );

      final List<DepositDto> deposits = await source.listDeposits();

      expect(deposits, hasLength(1));
    });

    test('falls back to unverified for unknown name-match values', () async {
      final source = build(<String, List<Map<String, dynamic>>>{
        'financial_deposits': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'dep-x',
            'currency_code': 'NGN',
            'amount': 100,
            'name_match_status': 'bogus',
          },
        ],
      });

      final List<DepositDto> deposits = await source.listDeposits();

      expect(deposits.single.nameMatchStatus, 'bogus');
      expect(
        DepositNameMatchStatus.fromPersisted(deposits.single.nameMatchStatus),
        DepositNameMatchStatus.unverified,
      );
    });

    test('surfaces REST failures as typed ApiException', () async {
      final source = SupabaseFinancialDepositRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          queryError: const ApiException(
            kind: ApiExceptionKind.server,
            message: 'deposits down',
            code: 'PLT999',
          ),
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

      await expectLater(
        source.listDeposits(),
        throwsA(isA<ApiException>().having(
          (ApiException e) => e.code,
          'code',
          'PLT999',
        )),
      );
    });
  });
}