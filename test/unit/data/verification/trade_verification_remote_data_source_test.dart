// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart' as norm;
import 'package:hivorr/data/datasources/remote/supabase_trade_verification_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:postgrest/postgrest.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

/// Unit coverage for [SupabaseTradeVerificationRemoteDataSource] (EP-02-11
/// §5.2) over the scripted Supabase transport: it must forward the exact RPC
/// params, unwrap the `PLT000` envelope, pass `entityId` through only when
/// provided, and normalize every failure into a typed [ApiException] — never
/// leaking a raw transport/Postgrest error (TT-01).
void main() {
  Map<String, dynamic> submissionData() => <String, dynamic>{
        'id': 'trade-sub-a',
        'entity_id': 'u1',
        'credential_id': 'cred-1',
        'submission_type': 'trade_proof',
        'status': 'pending',
        'submitted_at': '2026-01-01T00:00:00.000Z',
        'reviewed_at': null,
        'decision_notes': null,
      };

  Map<String, dynamic> statusData({String tradeStatus = 'approved'}) =>
      <String, dynamic>{
        'entity_id': 'u1',
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
        'identity_verified': true,
        'trade_verifications': <dynamic>[
          <String, dynamic>{
            'profession_id': 'p1',
            'trade_verification_status': tradeStatus,
          },
        ],
        'pending_submissions': 0,
        'total_submissions': 1,
      };

  Map<String, dynamic> envelope(Object data, {String code = 'PLT000'}) =>
      <String, dynamic>{
        'success': code == 'PLT000',
        'code': code,
        'message': code == 'PLT000' ? 'ok' : 'boom',
        'data': data,
      };

  SupabaseTradeVerificationRemoteDataSource build({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    Map<String, dynamic>? capturedSubmitParams,
    Map<String, dynamic>? capturedStatusParams,
  }) {
    final Map<String, Object? Function(Map<String, dynamic>)> handlers = <String,
        Object? Function(Map<String, dynamic>)>{
      'verification_submit': (Map<String, dynamic> params) {
        capturedSubmitParams?..clear()..addAll(params);
        return envelope(submissionData());
      },
      'verification_status_get': (Map<String, dynamic> params) {
        capturedStatusParams?..clear()..addAll(params);
        return envelope(statusData());
      },
    };
    handlers.addAll(rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{});
    final client = MockSupabaseClientFactory.create(rpcHandlers: handlers);
    return SupabaseTradeVerificationRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
  }

  group('submit()', () {
    test('forwards credentialId and the default trade_proof submission type',
        () async {
      final Map<String, dynamic> params = <String, dynamic>{};
      final ds = build(capturedSubmitParams: params);

      final VerificationSubmissionDto dto =
          await ds.submit(credentialId: 'cred-1');

      expect(params['p_credential_id'], 'cred-1');
      expect(params['p_submission_type'], 'trade_proof');
      expect(dto.id, 'trade-sub-a');
      expect(dto.entityId, 'u1');
      expect(dto.credentialId, 'cred-1');
      expect(dto.submissionType, 'trade_proof');
      expect(dto.status, 'pending');
    });

    test('honors an explicit submission type override', () async {
      final Map<String, dynamic> params = <String, dynamic>{};
      final ds = build(capturedSubmitParams: params);

      await ds.submit(
        credentialId: 'cred-2',
        submissionType: 'identity_document',
      );

      expect(params['p_credential_id'], 'cred-2');
      expect(params['p_submission_type'], 'identity_document');
    });

    test('unwraps the PLT000 envelope into a submission DTO', () async {
      final ds = build();

      final VerificationSubmissionDto dto =
          await ds.submit(credentialId: 'cred-1');

      expect(dto.id, 'trade-sub-a');
      expect(dto.submittedAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('getStatus()', () {
    test('omits p_entity_id when no entityId is supplied', () async {
      final Map<String, dynamic> params = <String, dynamic>{};
      final ds = build(capturedStatusParams: params);

      await ds.getStatus();

      expect(params.containsKey('p_entity_id'), isFalse);
    });

    test('passes p_entity_id when supplied', () async {
      final Map<String, dynamic> params = <String, dynamic>{};
      final ds = build(capturedStatusParams: params);

      await ds.getStatus(entityId: 'u9');

      expect(params['p_entity_id'], 'u9');
    });

    test('unwraps the envelope into a status aggregate DTO', () async {
      final ds = build();

      final VerificationStatusDto dto = await ds.getStatus();

      expect(dto.identityVerified, isTrue);
      expect(dto.tradeVerifications.single.professionId, 'p1');
      expect(dto.tradeVerifications.single.status, 'approved');
      expect(dto.entityId, 'u1');
    });
  });

  group('error normalization (TT-25..30)', () {
    Future<ApiException> captureSubmit(String code, {Object? data}) async {
      final ds = build(
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'verification_submit': (_) =>
              envelope(data ?? <String, dynamic>{}, code: code),
        },
      );
      try {
        await ds.submit(credentialId: 'cred-1');
      } on ApiException catch (e) {
        return e;
      }
      fail('expected ApiException for code $code');
    }

    test('PLT001 maps to auth', () async {
      final e = await captureSubmit('PLT001');
      expect(e.kind, ApiExceptionKind.auth);
      expect(e.code, 'PLT001');
    });

    test('PLT002 maps to forbidden', () async {
      final e = await captureSubmit('PLT002');
      expect(e.kind, ApiExceptionKind.forbidden);
    });

    test('PLT003 maps to validation', () async {
      final e = await captureSubmit('PLT003');
      expect(e.kind, ApiExceptionKind.validation);
    });

    test('PLT004 maps to notFound', () async {
      final e = await captureSubmit('PLT004');
      expect(e.kind, ApiExceptionKind.notFound);
    });

    test('PLT005 maps to conflict with the dedup message', () async {
      final e = await captureSubmit('PLT005');
      expect(e.kind, ApiExceptionKind.conflict);
      expect(e.message, VerificationEnvelopeParser.activeConflictMessage);
    });

    test('unknown non-PLT codes map to server', () async {
      final e = await captureSubmit('X42');
      expect(e.kind, ApiExceptionKind.server);
      expect(e.code, 'X42');
    });

    test('PLT999 maps to server (HTTP 500 fallback)', () async {
      final e = await captureSubmit('PLT999');
      expect(e.kind, ApiExceptionKind.server);
      expect(e.code, 'PLT999');
    });

    test('SQLSTATE 42501-prefixed codes map to forbidden', () async {
      final e = await captureSubmit('42501');
      expect(e.kind, ApiExceptionKind.forbidden);
    });

    test('a missing envelope fails closed to a server error', () async {
      final ds = build(
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'verification_submit': (_) => <String, dynamic>{},
        },
      );
      try {
        await ds.submit(credentialId: 'cred-1');
      } on ApiException catch (e) {
        expect(e.kind, ApiExceptionKind.server);
        return;
      }
      fail('expected ApiException for an empty envelope');
    });

    test('a malformed envelope (non-object data) maps to server', () async {
      final e = await captureSubmit('PLT000', data: <int>[1, 2, 3]);
      expect(e.kind, ApiExceptionKind.server);
    });
  });

  group('mapDataException normalization', () {
    test('rethrows typed ApiExceptions unchanged', () {
      const ApiException original = ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'dup',
        code: 'PLT005',
      );
      expect(norm.mapDataException(original), same(original));
    });

    test('maps SQLSTATE 42501 to forbidden', () {
      const PostgrestException pg = PostgrestException(
        message: 'policy violation',
        code: '42501',
      );
      expect(norm.mapDataException(pg).kind, ApiExceptionKind.forbidden);
    });

    test('maps SQLSTATE 23505 to conflict', () {
      const PostgrestException pg = PostgrestException(
        message: 'duplicate key',
        code: '23505',
      );
      expect(norm.mapDataException(pg).kind, ApiExceptionKind.conflict);
    });

    test('maps unknown codes to server without leaking the message', () {
      const PostgrestException pg = PostgrestException(
        message: 'internal',
        code: '500',
      );
      final ApiException e = norm.mapDataException(pg);
      expect(e.kind, ApiExceptionKind.server);
      expect(e.message, isNot(contains('internal')));
    });

    test('falls back to unknown for non-Postgrest transport errors', () {
      final ApiException e = norm.mapDataException(StateError('boom'));
      expect(e.kind, ApiExceptionKind.unknown);
      expect(e.message, isNot(contains('boom')));
    });
  });
}