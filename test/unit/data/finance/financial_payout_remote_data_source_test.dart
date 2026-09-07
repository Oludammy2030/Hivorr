import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_payout_remote_data_source.dart';
import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

void main() {
  SupabaseFinancialPayoutRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)> rpcHandlers,
  ) =>
      SupabaseFinancialPayoutRemoteDataSource(
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

  Map<String, dynamic> error(String code) => <String, dynamic>{
        'success': false,
        'code': code,
        'message': 'fail',
        'data': <String, dynamic>{},
      };

  group('SupabaseFinancialPayoutRemoteDataSource.bindAccount', () {
    test('calls financial_payout_account_bind with the form params', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_payout_account_bind': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'payout_account_id': 'acc-1',
            'currency_code': 'NGN',
            'status': 'pending',
          });
        },
      });

      final PayoutBindDto dto = await source.bindAccount(
        currencyCode: 'NGN',
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
      );

      expect(seenParams, containsPair('p_currency_code', 'NGN'));
      expect(seenParams, containsPair('p_bank_name', 'Guaranty Trust'));
      expect(seenParams, containsPair('p_account_number', '0123456789'));
      expect(seenParams, containsPair('p_account_name', 'John Doe'));
      expect(dto.payoutAccountId, 'acc-1');
      expect(dto.currencyCode, 'NGN');
      expect(dto.status, 'pending');
    });

    test('maps PLT003 validation envelope to a validation ApiException',
        () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_payout_account_bind': (_) => error('PLT003'),
      });

      await expectLater(
        source.bindAccount(
          currencyCode: 'NGN',
          bankName: 'B',
          accountNumber: '0123456789',
          accountName: 'N',
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT003')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              ),
        ),
      );
    });

    test('maps PLT001 envelope to an auth ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_payout_account_bind': (_) => error('PLT001'),
      });

      await expectLater(
        source.bindAccount(
          currencyCode: 'NGN',
          bankName: 'B',
          accountNumber: '0123456789',
          accountName: 'N',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.auth,
          ),
        ),
      );
    });

    test('throws a server ApiException on a malformed envelope', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_payout_account_bind': (_) => <String, dynamic>{
            'success': true,
            'code': 'PLT000',
            'data': 'not-an-object',
          },
      });

      await expectLater(
        source.bindAccount(
          currencyCode: 'NGN',
          bankName: 'B',
          accountNumber: '0123456789',
          accountName: 'N',
        ),
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

  group('SupabaseFinancialPayoutRemoteDataSource.withdraw', () {
    test('calls financial_withdraw with account id and amount', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_withdraw': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'payout_id': 'pay-1',
            'amount': 50000,
            'fee': 0,
            'net_amount': 50000,
            'cashout_remaining': 450000,
          });
        },
      });

      final WithdrawalDto dto = await source.withdraw(
        payoutAccountId: 'acc-1',
        amount: 50000,
      );

      expect(seenParams, containsPair('p_payout_account_id', 'acc-1'));
      expect(seenParams, containsPair('p_amount', 50000));
      expect(dto.payoutId, 'pay-1');
      expect(dto.amount, 50000);
      expect(dto.cashoutRemaining, 450000);
    });

    test('maps PLT006 envelope to a conflict ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_withdraw': (_) => error('PLT006'),
      });

      await expectLater(
        source.withdraw(payoutAccountId: 'acc-1', amount: 50000),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT006')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.conflict,
              ),
        ),
      );
    });

    test('maps PLT002 envelope to a forbidden ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_withdraw': (_) => error('PLT002'),
      });

      await expectLater(
        source.withdraw(payoutAccountId: 'acc-1', amount: 100),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.forbidden,
          ),
        ),
      );
    });

    test('maps PLT999 envelope to a server ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_withdraw': (_) => error('PLT999'),
      });

      await expectLater(
        source.withdraw(payoutAccountId: 'acc-1', amount: 100),
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