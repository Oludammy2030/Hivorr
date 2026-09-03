import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_kyc_remote_data_source.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

void main() {
  SupabaseKycRemoteDataSource build([
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ]) =>
      SupabaseKycRemoteDataSource(
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

  group('SupabaseKycRemoteDataSource.getKycLevel', () {
    test('calls verification_kyc_level_get and maps the level', () async {
      String? seenFn;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_kyc_level_get': (Map<String, dynamic> body) {
          seenFn = 'verification_kyc_level_get';
          return ok(<String, dynamic>{
            'tier_code': 'tier_1',
            'status': 'active',
            'limits': <String, dynamic>{
              'daily': 500000,
              'weekly': 2000000,
              'monthly': 8000000,
              'cashout': 1000000,
            },
          });
        },
      });

      final KycLevelDto dto = await source.getKycLevel();

      expect(seenFn, 'verification_kyc_level_get');
      expect(dto.tierCode, 'tier_1');
      expect(dto.status, 'active');
      expect(dto.limits.cashout, 1000000);
    });
  });

  group('SupabaseKycRemoteDataSource.getLimits', () {
    test('calls verification_limits_get and maps limits only', () async {
      String? seenFn;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_limits_get': (Map<String, dynamic> body) {
          seenFn = 'verification_limits_get';
          return ok(<String, dynamic>{
            'tier_code': 'tier_1',
            'daily': 100,
            'weekly': 200,
            'monthly': 300,
            'cashout': 400,
          });
        },
      });

      final KycLimitsDto dto = await source.getLimits();

      expect(seenFn, 'verification_limits_get');
      expect(dto.daily, 100);
      expect(dto.monthly, 300);
      expect(dto.cashout, 400);
    });
  });

  group('SupabaseKycRemoteDataSource.getStatus', () {
    test('calls verification_status_get and maps the aggregate', () async {
      String? seenFn;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (Map<String, dynamic> body) {
          seenFn = 'verification_status_get';
          return ok(<String, dynamic>{
            'entity_id': 'u1',
            'kyc': <String, dynamic>{
              'tier_code': 'tier_1',
              'status': 'active',
              'limits': <String, dynamic>{
                'daily': 500000,
                'weekly': 2000000,
                'monthly': 8000000,
                'cashout': 1000000,
              },
            },
            'identity_verified': true,
            'trade_verifications': <dynamic>[],
            'pending_submissions': 0,
            'total_submissions': 2,
          });
        },
      });

      final VerificationStatusDto dto = await source.getStatus();

      expect(seenFn, 'verification_status_get');
      expect(dto.entityId, 'u1');
      expect(dto.identityVerified, isTrue);
      expect(dto.kyc.tierCode, 'tier_1');
      expect(dto.totalSubmissions, 2);
    });

    test('maps a PLT001 envelope to auth ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
              'code': 'PLT001',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)),
      );
    });

    test('throws server when envelope data is not an object', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
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
  });

  group('error envelopes across RPCs', () {
    test('maps PLT003 to validation on getKycLevel', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_kyc_level_get': (_) => <String, dynamic>{
              'code': 'PLT003',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getKycLevel(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)
            .having((ApiException e) => e.code, 'code', 'PLT003')),
      );
    });

    test('maps PLT004 to notFound on getLimits', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_limits_get': (_) => <String, dynamic>{
              'code': 'PLT004',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getLimits(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.notFound)),
      );
    });

    test('maps PLT002 to forbidden on getStatus', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
              'code': 'PLT002',
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

    test('maps an unknown code to server on getLimits', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_limits_get': (_) => <String, dynamic>{
              'code': 'PLT999',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getLimits(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
      );
    });

    test('maps missing code to server on getKycLevel', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_kyc_level_get': (_) => <String, dynamic>{
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getKycLevel(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
      );
    });

    test('maps PLT005 to conflict on getStatus', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
              'code': 'PLT005',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)),
      );
    });

    test('throws server when getLimits data is not an object', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_limits_get': (_) => <String, dynamic>{
              'success': true,
              'code': 'PLT000',
              'data': 'oops',
            },
      });
      expect(
        () => source.getLimits(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
      );
    });
  });

  group('parameterized getStatus', () {
    test('passes a supplied entity id into the RPC', () async {
      Object? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'entity_id': 'admin_1',
            'kyc': <String, dynamic>{
              'tier_code': 'tier_0',
              'status': 'pending',
              'limits': <String, dynamic>{
                'daily': 0,
                'weekly': 0,
                'monthly': 0,
                'cashout': 0,
              },
            },
            'identity_verified': false,
            'trade_verifications': <dynamic>[],
            'pending_submissions': 0,
            'total_submissions': 0,
          });
        },
      });

      await source.getStatus(entityId: 'admin_1');

      expect(seenParams, isNotNull);
      expect((seenParams! as Map<String, dynamic>)['p_entity_id'], 'admin_1');
    });
  });
}
