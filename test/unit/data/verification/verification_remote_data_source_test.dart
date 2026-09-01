import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

void main() {
  Map<String, dynamic> submissionData({
    String id = 'sub-1',
    String status = 'pending',
  }) =>
      <String, dynamic>{
        'id': id,
        'entity_id': 'u1',
        'credential_id': 'cred-1',
        'submission_type': 'identity_document',
        'status': status,
        'submitted_at': '2026-01-01T00:00:00.000Z',
        'reviewed_at': null,
        'decision_notes': null,
      };

  Map<String, dynamic> statusData({
    String tier = 'tier_0',
    bool identityVerified = false,
    int pending = 1,
    int total = 1,
  }) =>
      <String, dynamic>{
        'entity_id': 'u1',
        'kyc': <String, dynamic>{
          'tier_code': tier,
          'status': 'pending',
          'limits': <String, dynamic>{
            'daily': 0, 'weekly': 0, 'monthly': 0, 'cashout': 0,
          },
        },
        'identity_verified': identityVerified,
        'trade_verifications': <dynamic>[],
        'pending_submissions': pending,
        'total_submissions': total,
      };

  SupabaseVerificationRemoteDataSource build([
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ]) =>
      SupabaseVerificationRemoteDataSource(
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

  group('SupabaseVerificationRemoteDataSource.submit', () {
    test('calls verification_submit with the credential id', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_submit': (Map<String, dynamic> body) {
          seenFn = 'verification_submit';
          seenParams = body;
          return ok(submissionData());
        },
      });

      final VerificationSubmissionDto dto = await source.submit(
        credentialId: 'cred-1',
        submissionType: 'identity_document',
      );

      expect(seenFn, 'verification_submit');
      expect(seenParams!['p_credential_id'], 'cred-1');
      expect(seenParams!['p_submission_type'], 'identity_document');
      expect(dto.id, 'sub-1');
      expect(dto.credentialId, 'cred-1');
    });

    test('omits submission_type when null', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_submit': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(submissionData());
        },
      });

      await source.submit(credentialId: 'cred-1');

      expect(seenParams!, containsPair('p_credential_id', 'cred-1'));
      expect(seenParams!.containsKey('p_submission_type'), isFalse);
    });

    test('maps a PLT005 conflict envelope to a conflict ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_submit': (_) => <String, dynamic>{
              'code': 'PLT005',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.submit(credentialId: 'cred-1'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)
            .having((ApiException e) => e.code, 'code', 'PLT005')),
      );
    });

    test('throws auth on PLT001 when not signed in', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_submit': (_) => <String, dynamic>{
              'code': 'PLT001',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.submit(credentialId: 'cred-1'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)),
      );
    });
  });

  group('SupabaseVerificationRemoteDataSource.getStatus', () {
    test('calls verification_status_get without params when entityId null',
        () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (Map<String, dynamic> body) {
          seenFn = 'verification_status_get';
          seenParams = body;
          return ok(statusData());
        },
      });

      final VerificationStatusDto dto = await source.getStatus();

      expect(seenFn, 'verification_status_get');
      expect(seenParams, isEmpty);
      expect(dto.entityId, 'u1');
      expect(dto.identityVerified, isFalse);
    });

    test('passes p_entity_id when supplied', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(statusData());
        },
      });

      await source.getStatus(entityId: 'u1');

      expect(seenParams!['p_entity_id'], 'u1');
    });

    test('maps verified aggregate incl. kyc + counts', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => ok(statusData(
              tier: 'tier_1',
              identityVerified: true,
              pending: 0,
              total: 3,
            )),
      });

      final VerificationStatusDto dto = await source.getStatus();

      expect(dto.identityVerified, isTrue);
      expect(dto.kyc.tierCode, 'tier_1');
      expect(dto.pendingSubmissions, 0);
      expect(dto.totalSubmissions, 3);
    });

    test('maps PLT004 to notFound for cross-entity access', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
              'code': 'PLT004',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getStatus(entityId: 'other'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.notFound)),
      );
    });

    test('maps 42501 SQL error to forbidden', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
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

  group('SupabaseVerificationRemoteDataSource.getKycLevel', () {
    test('returns the assigned KYC level', () async {
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
      expect(dto.limits.daily, 500000);
    });
  });

  group('SupabaseVerificationRemoteDataSource.getLimits', () {
    test('returns tier limits', () async {
      String? seenFn;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_limits_get': (Map<String, dynamic> body) {
          seenFn = 'verification_limits_get';
          return ok(<String, dynamic>{
            'tier_code': 'tier_1',
            'status': 'active',
            'limits': <String, dynamic>{
              'daily': 100,
              'weekly': 200,
              'monthly': 300,
              'cashout': 400,
            },
          });
        },
      });

      final KycLevelDto dto = await source.getLimits();

      expect(seenFn, 'verification_limits_get');
      expect(dto.limits.monthly, 300);
      expect(dto.limits.cashout, 400);
    });
  });

  group('envelope error mapping', () {
    test('falls back to server kind for unknown codes', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_status_get': (_) => <String, dynamic>{
              'code': 'X999',
              'data': <String, dynamic>{},
            },
      });
      expect(
        () => source.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
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
}
