import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/datasources/remote/supabase_escrow_remote_data_source.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

void main() {
  SupabaseEscrowRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers, {
    bool writeViaProxy = false,
  }) =>
      SupabaseEscrowRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(rpcHandlers: rpcHandlers),
        exceptionMapper: const ApiExceptionMapper(),
        writeViaProxy: writeViaProxy,
      );

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  Map<String, dynamic> envelopeData({
    String escrowStatus = 'funded',
    List<Map<String, dynamic>> milestones = const <Map<String, dynamic>>[],
  }) =>
      <String, dynamic>{
        'escrow': <String, dynamic>{
          'id': 'escrow-1',
          'financial_profile_id': 'profile-1',
          'payer_entity_id': 'entity-payer',
          'payee_entity_id': 'entity-payee',
          'currency_code': 'NGN',
          'total_amount': 50000,
          'released_amount': 0,
          'refunded_amount': 0,
          'status': escrowStatus,
          'external_reference': 'ORD-2026-000123',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        'milestones': milestones,
      };

  group('SupabaseEscrowRemoteDataSource.getById', () {
    test('calls financial_escrow_get with p_escrow_id and maps envelope',
        () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (Map<String, dynamic> body) {
          seenFn = 'financial_escrow_get';
          seenParams = body;
          return ok(envelopeData(milestones: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'ms-1',
              'escrow_id': 'escrow-1',
              'milestone_number': 1,
              'title': 'Design sign-off',
              'amount': 50000,
              'status': 'pending',
              'sort_order': 1,
              'created_at': '2026-01-01T00:00:00.000Z',
            },
          ]));
        },
      });

      final EscrowDetailDto dto = await source.getById('escrow-1');

      expect(seenFn, 'financial_escrow_get');
      expect(seenParams, containsPair('p_escrow_id', 'escrow-1'));
      expect(dto.escrow.id, 'escrow-1');
      expect(dto.escrow.status, 'funded');
      expect(dto.escrow.currencyCode, 'NGN');
      expect(dto.escrow.externalReference, 'ORD-2026-000123');
      expect(dto.milestones, hasLength(1));
      expect(dto.milestones.single.status, 'pending');
      expect(dto.transactions, isEmpty);
    });

    test('maps empty transactions when envelope has no transactions key',
        () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => ok(envelopeData()),
      });

      final EscrowDetailDto dto = await source.getById('escrow-1');

      expect(dto.transactions, isEmpty);
    });

    test('throws mapped ApiException on non-envelope response', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT002',
            'message': 'forbidden',
          },
      });

      await expectLater(
        source.getById('escrow-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT002',
          ),
        ),
      );
    });

    test('maps RPC transport failure to ApiException', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => throw StateError('network down'),
      });

      await expectLater(source.getById('escrow-1'), throwsA(isA<ApiException>()));
    });
  });

  group('SupabaseEscrowRemoteDataSource.getByProject', () {
    test('enumerates known ids via financial_escrow_get', () async {
      final seen = <String>[];
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (Map<String, dynamic> body) {
          seen.add(body['p_escrow_id'] as String);
          return ok(envelopeData());
        },
      });

      final List<EscrowDto> result = await source.getByProject(const <String>[
        'escrow-1',
        'escrow-2',
      ]);

      expect(seen, <String>['escrow-1', 'escrow-2']);
      expect(result, hasLength(2));
    });
  });

  group('SupabaseEscrowRemoteDataSource read error mapping', () {
    test('maps 401 PLT001 auth envelope to auth', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT001',
            'message': 'auth required',
          },
      });

      await expectLater(
        source.getById('escrow-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.auth,
              )
              .having((ApiException e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('maps 400/422 PLT003 validation envelope to validation', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT003',
            'message': 'milestone sum mismatch',
          },
      });

      await expectLater(
        source.getById('escrow-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              )
              .having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('maps 404 PLT004 notFound envelope to notFound', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT004',
            'message': 'escrow not found',
          },
      });

      await expectLater(
        source.getById('escrow-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.notFound,
              )
              .having((ApiException e) => e.code, 'code', 'PLT004'),
        ),
      );
    });

    test('maps 5xx PLT999 server envelope to server', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'financial_escrow_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT999',
            'message': 'internal error',
          },
      });

      await expectLater(
        source.getById('escrow-1'),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.server,
              )
              .having((ApiException e) => e.code, 'code', 'PLT999'),
        ),
      );
    });
  });

  group('SupabaseEscrowRemoteDataSource write seam', () {
    test('writeViaProxy defaults false and gates every write', () async {
      final source = build(null);

      expect(source.writeViaProxy, isFalse);
      await expectLater(
        source.createEscrow(
          payerEntityId: 'p',
          payeeEntityId: 'ee',
          currencyCode: 'NGN',
          totalAmount: 50000,
          milestones: const <EscrowMilestoneInput>[],
        ),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        source.fundEscrow(escrowId: 'escrow-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        source.completeMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        source.releaseMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        source.releaseFinal(escrowId: 'escrow-1'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
      await expectLater(
        source.refundEscrow(escrowId: 'escrow-1', reason: 'n/a'),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
    });

    test(
        'message of the unavailable exception surfaces support-team guidance '
        '(FV-48)', () {
      const EscrowWriteUnavailableException e = EscrowWriteUnavailableException();
      expect(e.message, contains('support team'));
      expect(e.kind, ApiExceptionKind.forbidden);
    });

    test('createEscrow with seam on throws UnimplementedError — proxy pending '
        '(EP-02-18), never a direct write RPC', () async {
      var rpcCalls = 0;
      final source = build(
        <String, Object? Function(Map<String, dynamic>)>{
          'financial_escrow_get': (_) {
            rpcCalls++;
            return ok(envelopeData());
          },
        },
        writeViaProxy: true,
      );

      await expectLater(
        source.createEscrow(
          payerEntityId: 'p',
          payeeEntityId: 'ee',
          currencyCode: 'NGN',
          totalAmount: 50000,
          milestones: const <EscrowMilestoneInput>[],
        ),
        throwsA(isA<UnimplementedError>()),
      );

      // No read or write RPC ever invoked through the seam path.
      expect(rpcCalls, 0);
    });

    test('fundEscrow with seam on throws UnimplementedError — proxy pending '
        '(EP-02-18), never a direct write RPC', () async {
      var rpcCalls = 0;
      final source = build(
        <String, Object? Function(Map<String, dynamic>)>{
          'financial_escrow_get': (_) {
            rpcCalls++;
            return ok(envelopeData());
          },
        },
        writeViaProxy: true,
      );

      await expectLater(
        source.fundEscrow(escrowId: 'escrow-1'),
        throwsA(isA<UnimplementedError>()),
      );

      // No read or write RPC ever invoked through the seam path.
      expect(rpcCalls, 0);
    });
  });
}