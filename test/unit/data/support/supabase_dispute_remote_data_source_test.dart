import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_dispute_remote_data_source.dart';
import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

void main() {
  SupabaseDisputeRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ) =>
      SupabaseDisputeRemoteDataSource(
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

  Map<String, dynamic> envelopeData({
    String status = 'open',
    String disputeType = 'non_delivery',
  }) =>
      <String, dynamic>{
        'id': 'dispute-1',
        'escrow_id': 'escrow-1',
        'filer_entity_id': 'entity-filer',
        'counterparty_entity_id': 'entity-counterparty',
        'dispute_type': disputeType,
        'status': status,
        'reason': 'Work did not match the agreed milestone description.',
        'desired_outcome': 'release_to_payee',
        'priority': 'medium',
        'filed_at': '2026-01-01T00:00:00.000Z',
        'metadata': <String, dynamic>{},
      };

  group('SupabaseDisputeRemoteDataSource.listDisputes', () {
    test('calls dispute_list and maps the {disputes:[...]} envelope', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (Map<String, dynamic> body) {
          seenFn = 'dispute_list';
          seenParams = body;
          return ok(<String, dynamic>{
            'disputes': <dynamic>[envelopeData()],
          });
        },
      });

      final DisputeListEnvelopeDto dto = await source.listDisputes();

      expect(seenFn, 'dispute_list');
      expect(seenParams, isNotNull);
      expect(seenParams!.containsKey('p_status'), isFalse);
      expect(dto.disputes, hasLength(1));
      expect(dto.disputes.single.status, 'open');
      expect(dto.disputes.single.disputeType, 'non_delivery');
    });

    test('passes p_status when a filter is provided', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'disputes': <dynamic>[envelopeData(status: 'under_review')],
          });
        },
      });

      final DisputeListEnvelopeDto dto =
          await source.listDisputes(status: 'under_review');

      expect(seenParams, containsPair('p_status', 'under_review'));
      expect(dto.disputes.single.status, 'under_review');
    });

    test('maps empty disputes array to an empty list', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (_) => ok(<String, dynamic>{'disputes': <dynamic>[]}),
      });

      final DisputeListEnvelopeDto dto = await source.listDisputes();

      expect(dto.disputes, isEmpty);
    });
  });

  group('SupabaseDisputeRemoteDataSource.getCase', () {
    test('calls dispute_get and maps {case, evidence, resolution}', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_get': (Map<String, dynamic> body) {
          seenFn = 'dispute_get';
          seenParams = body;
          return ok(<String, dynamic>{
            'case': envelopeData(status: 'under_review'),
            'evidence': <dynamic>[
              <String, dynamic>{
                'id': 'ev-1',
                'case_id': 'dispute-1',
                'submitted_by': 'entity-filer',
                'evidence_type': 'screenshot',
                'title': 'Approval screenshot',
                'description': 'See attachment',
                'file_url': 'entity-filer/dispute-1/abc.png',
                'file_metadata': <String, dynamic>{
                  'mimeType': 'image/png',
                  'sizeBytes': 1024,
                  'originalName': 'shot.png',
                },
                'created_at': '2026-01-02T00:00:00.000Z',
              },
            ],
            'resolution': <String, dynamic>{
              'id': 'res-1',
              'case_id': 'dispute-1',
              'resolved_by': 'admin-1',
              'resolution_type': 'release_to_payee',
              'reasoning': 'Funds released to the provider.',
              'payer_refund_amount': 0,
              'payee_release_amount': 50000,
              'notes': null,
              'resolved_at': '2026-01-03T00:00:00.000Z',
              'created_at': '2026-01-03T00:00:00.000Z',
            },
          });
        },
      });

      final DisputeCaseDetailEnvelopeDto dto = await source.getCase('dispute-1');

      expect(seenFn, 'dispute_get');
      expect(seenParams, containsPair('p_case_id', 'dispute-1'));
      expect(dto.caseDto.id, 'dispute-1');
      expect(dto.caseDto.status, 'under_review');
      expect(dto.evidence, hasLength(1));
      expect(dto.evidence.single.title, 'Approval screenshot');
      expect(dto.evidence.single.fileUrl, 'entity-filer/dispute-1/abc.png');
      expect(dto.resolution, isNotNull);
      expect(dto.resolution!.resolutionType, 'release_to_payee');
      expect(dto.resolution!.payeeReleaseAmount, 50000);
    });

    test('maps resolution:null to a null resolution instead of throwing',
        () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_get': (_) => ok(<String, dynamic>{
              'case': envelopeData(),
              'evidence': <dynamic>[],
              'resolution': null,
            }),
      });

      final DisputeCaseDetailEnvelopeDto dto = await source.getCase('dispute-1');

      expect(dto.caseDto.status, 'open');
      expect(dto.evidence, isEmpty);
      expect(dto.resolution, isNull);
    });
  });

  group('SupabaseDisputeRemoteDataSource.fileDispute', () {
    test('calls dispute_file with all p_ params and maps the case', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_file': (Map<String, dynamic> body) {
          seenFn = 'dispute_file';
          seenParams = body;
          return ok(envelopeData(status: 'open'));
        },
      });

      final DisputeCaseDto dto = await source.fileDispute(
        escrowId: 'escrow-1',
        disputeType: 'non_delivery',
        reason: 'Work did not match the agreed milestone description.',
        desiredOutcome: 'release_to_payee',
        priority: 'high',
      );

      expect(seenFn, 'dispute_file');
      expect(seenParams, containsPair('p_escrow_id', 'escrow-1'));
      expect(seenParams, containsPair('p_dispute_type', 'non_delivery'));
      expect(
        seenParams,
        containsPair('p_reason', 'Work did not match the agreed milestone description.'),
      );
      expect(seenParams, containsPair('p_desired_outcome', 'release_to_payee'));
      expect(seenParams, containsPair('p_priority', 'high'));
      expect(dto.status, 'open');
    });

    test('omits p_desired_outcome when null and defaults priority to medium',
        () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_file': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(envelopeData());
        },
      });

      await source.fileDispute(
        escrowId: 'escrow-1',
        disputeType: 'fraud',
        reason: 'Work did not match the agreed milestone description.',
      );

      expect(seenParams!.containsKey('p_desired_outcome'), isFalse);
      expect(seenParams, containsPair('p_priority', 'medium'));
    });
  });

  group('SupabaseDisputeRemoteDataSource.submitEvidence', () {
    test('calls dispute_submit_evidence with metadata and maps the row',
        () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_submit_evidence': (Map<String, dynamic> body) {
          seenFn = 'dispute_submit_evidence';
          seenParams = body;
          return ok(<String, dynamic>{
            'id': 'ev-1',
            'case_id': 'dispute-1',
            'submitted_by': 'entity-filer',
            'evidence_type': 'screenshot',
            'title': 'Approval screenshot',
            'description': 'See attachment',
            'file_url': 'entity-filer/dispute-1/abc.png',
            'file_metadata': <String, dynamic>{
              'mimeType': 'image/png',
            },
            'created_at': '2026-01-02T00:00:00.000Z',
          });
        },
      });

      final DisputeEvidenceDto dto = await source.submitEvidence(
        caseId: 'dispute-1',
        evidenceType: 'screenshot',
        title: 'Approval screenshot',
        description: 'See attachment',
        fileUrl: 'entity-filer/dispute-1/abc.png',
        fileMetadata: <String, dynamic>{'mimeType': 'image/png'},
      );

      expect(seenFn, 'dispute_submit_evidence');
      expect(seenParams, containsPair('p_case_id', 'dispute-1'));
      expect(seenParams, containsPair('p_evidence_type', 'screenshot'));
      expect(seenParams, containsPair('p_title', 'Approval screenshot'));
      expect(seenParams, containsPair('p_description', 'See attachment'));
      expect(
        seenParams,
        containsPair('p_file_url', 'entity-filer/dispute-1/abc.png'),
      );
      expect(seenParams!['p_file_metadata'], <String, dynamic>{
        'mimeType': 'image/png',
      });
      expect(dto.id, 'ev-1');
      expect(dto.evidenceType, 'screenshot');
    });

    test('omits nullable description/file_url for description-type evidence',
        () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_submit_evidence': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'id': 'ev-2',
            'case_id': 'dispute-1',
            'submitted_by': 'entity-filer',
            'evidence_type': 'description',
            'title': 'Written account',
            'description': null,
            'file_url': null,
            'file_metadata': <String, dynamic>{},
            'created_at': '2026-01-02T00:00:00.000Z',
          });
        },
      });

      final DisputeEvidenceDto dto = await source.submitEvidence(
        caseId: 'dispute-1',
        evidenceType: 'description',
        title: 'Written account',
      );

      expect(seenParams!.containsKey('p_description'), isFalse);
      expect(seenParams!.containsKey('p_file_url'), isFalse);
      expect(dto.fileUrl, isNull);
      expect(dto.description, isNull);
    });
  });

  group('SupabaseDisputeRemoteDataSource.withdrawDispute', () {
    test('calls dispute_withdraw (SECURITY DEFINER) as a plain RPC', () async {
      String? seenFn;
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_withdraw': (Map<String, dynamic> body) {
          seenFn = 'dispute_withdraw';
          seenParams = body;
          return ok(envelopeData(status: 'withdrawn'));
        },
      });

      final DisputeCaseDto dto = await source.withdrawDispute('dispute-1');

      expect(seenFn, 'dispute_withdraw');
      expect(seenParams, containsPair('p_case_id', 'dispute-1'));
      expect(dto.status, 'withdrawn');
    });
  });

  group('SupabaseDisputeRemoteDataSource envelope error mapping', () {
    test('PLT001 auth', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT001',
            'message': 'auth required',
          },
      });

      await expectLater(
        source.listDisputes(),
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

    test('PLT002 forbidden', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT002',
            'message': 'forbidden',
          },
      });

      await expectLater(
        source.listDisputes(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.forbidden,
          ),
        ),
      );
    });

    test('PLT003 validation', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT003',
            'message': 'reason too short',
          },
      });

      await expectLater(
        source.getCase('dispute-1'),
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

    test('PLT004 notFound', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_get': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT004',
            'message': 'not found',
          },
      });

      await expectLater(
        source.getCase('missing'),
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

    test('PLT005 conflict', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_file': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT005',
            'message': 'active dispute already exists for this escrow',
          },
      });

      await expectLater(
        source.fileDispute(
          escrowId: 'escrow-1',
          disputeType: 'fraud',
          reason: 'Work did not match the agreed milestone description.',
        ),
        throwsA(
          isA<ApiException>()
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.conflict,
              )
              .having((ApiException e) => e.code, 'code', 'PLT005'),
        ),
      );
    });

    test('PLT999 server', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (_) => <String, dynamic>{
            'success': false,
            'code': 'PLT999',
            'message': 'internal error',
          },
      });

      await expectLater(
        source.listDisputes(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });

    test('transport failure maps to ApiException (never raw)', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'dispute_list': (_) => throw StateError('network down'),
      });

      await expectLater(source.listDisputes(), throwsA(isA<ApiException>()));
    });
  });

  group('DisputeRemoteDataSource contract surface', () {
    test('the 5-RPC client surface is exact and dispute_resolve is absent',
        () {
      final String contract =
          File('lib/data/datasources/remote/dispute_remote_data_source.dart')
              .readAsStringSync();
      final String impl =
          File('lib/data/datasources/remote/supabase_dispute_remote_data_source.dart')
              .readAsStringSync();

      expect(contract, contains('dispute_list'));
      expect(contract, contains('dispute_get'));
      expect(contract, contains('dispute_file'));
      expect(contract, contains('dispute_submit_evidence'));
      expect(contract, contains('dispute_withdraw'));
      // The server-granted resolver is never wired as a client method or an
      // RPC call (20260829120005:874 — absent, not just unreachable). The word
      // may appear in a doc comment explaining the omission, so assert there is
      // no `resolve` method declaration and no `rpc(... dispute_resolve)` call.
      expect(
        RegExp(r'\bresolve[A-Za-z]*\s*\(', multiLine: true).hasMatch(contract),
        isFalse,
        reason: 'no resolve-* method may exist on the client contract',
      );
      // `dispute_resolve` may appear only as a doc-comment explanation of the
      // omission, never as an actual `.rpc('dispute_resolve', ...)` call.
      expect(
        RegExp(r"rpc\s*\(\s*'dispute_resolve'").hasMatch(impl),
        isFalse,
        reason: 'dispute_resolve must never be invoked from the client',
      );
      expect(impl, contains('supabase.rpc'));
    });
  });
}