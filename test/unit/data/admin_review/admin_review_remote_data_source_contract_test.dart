import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_admin_review_remote_data_source.dart';
import 'package:hivorr/data/models/admin_review_dto.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

/// Canonical RPC response envelopes (locked by test 021).
///
/// These fixtures reproduce the exact JSON shape the server returns. Any key
/// rename or structural change in the RPCs will surface as a test failure here
/// before it hits production.
void main() {
  Map<String, dynamic> queueEntryData({
    String id = 'ffffffff-0000-0000-0000-000000000073',
    String entityId = '22222222-2222-2222-2222-222222222222',
    String entityDisplayName = 'Contract Admin Co',
    String? entityLegalName = 'Contract Admin Sdn Bhd',
    String? entityAvatarPath = 'avatars/22222222/avatar.png',
    String credentialId = 'ffffffff-0000-0000-0000-000000000072',
    String credentialTitle = 'Contract Trade Cert',
    String credentialKind = 'trade_proof',
    String? documentPath = 'docs/cred-001.pdf',
    String? professionId = 'ffffffff-0000-0000-0000-000000000071',
    String? professionName = 'Contract Prof',
    String submissionType = 'trade_proof',
    String status = 'pending',
    String submittedAt = '2026-01-15T10:30:00Z',
    String? assignedReviewer,
    String? decisionNotes,
  }) =>
      <String, dynamic>{
        'id': id,
        'entity_id': entityId,
        'entity_display_name': entityDisplayName,
        'entity_legal_name': entityLegalName,
        'entity_avatar_path': entityAvatarPath,
        'credential_id': credentialId,
        'credential_title': credentialTitle,
        'credential_kind': credentialKind,
        'document_path': documentPath,
        'profession_id': professionId,
        'profession_name': professionName,
        'submission_type': submissionType,
        'status': status,
        'submitted_at': submittedAt,
        'assigned_reviewer': assignedReviewer,
        'decision_notes': decisionNotes,
      };

  Map<String, dynamic> auditEntryData({
    String id = 'aabbccdd-0000-0000-0000-000000000001',
    String eventType = 'submitted',
    String? subjectType = 'submission',
    String? subjectId = 'ffffffff-0000-0000-0000-000000000073',
    String? fromState,
    String? toState = 'pending',
    String? actorId = '22222222-2222-2222-2222-222222222222',
    Map<String, dynamic>? details,
    String createdAt = '2026-01-15T10:30:00Z',
  }) =>
      <String, dynamic>{
        'id': id,
        'event_type': eventType,
        'subject_type': subjectType,
        'subject_id': subjectId,
        'from_state': fromState,
        'to_state': toState,
        'actor_id': actorId,
        'details': details,
        'created_at': createdAt,
      };

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  SupabaseAdminReviewRemoteDataSource build([
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    Map<String, List<Map<String, dynamic>>>? queryResults,
  ]) =>
      SupabaseAdminReviewRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          rpcHandlers: rpcHandlers,
          queryResults: queryResults,
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

  group('getReviewQueue — canonical envelope', () {
    test('parses the data.submissions array into DTOs', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_queue_get': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'submissions': <dynamic>[
              queueEntryData(),
              queueEntryData(
                id: 'ffffffff-0000-0000-0000-000000000074',
                submissionType: 'identity_document',
                credentialKind: 'identity_document',
                credentialTitle: 'ID Card',
                status: 'in_review',
              ),
            ],
            'total_count': 2,
          });
        },
      });

      final List<AdminReviewQueueEntryDto> entries =
          await source.getReviewQueue(limit: 20, offset: 0);

      expect(seenParams, isNotNull);
      expect(seenParams!['p_limit'], 20);
      expect(seenParams!['p_offset'], 0);

      expect(entries, hasLength(2));

      final AdminReviewQueueEntryDto first = entries.first;
      expect(first.submissionId, 'ffffffff-0000-0000-0000-000000000073');
      expect(first.entityId, '22222222-2222-2222-2222-222222222222');
      expect(first.entityName, 'Contract Admin Co');
      expect(first.entityLegalName, 'Contract Admin Sdn Bhd');
      expect(first.entityAvatarPath, 'avatars/22222222/avatar.png');
      expect(first.credentialId, 'ffffffff-0000-0000-0000-000000000072');
      expect(first.credentialType, 'trade_proof');
      expect(first.credentialName, 'Contract Trade Cert');
      expect(first.documentPath, 'docs/cred-001.pdf');
      expect(first.professionId, 'ffffffff-0000-0000-0000-000000000071');
      expect(first.professionName, 'Contract Prof');
      expect(first.submissionType, 'trade_proof');
      expect(first.status, 'pending');
      expect(first.submittedAt, DateTime.utc(2026, 1, 15, 10, 30));

      final AdminReviewQueueEntryDto second = entries[1];
      expect(second.credentialType, 'identity_document');
      expect(second.credentialName, 'ID Card');
      expect(second.status, 'in_review');
    });

    test('passes p_submission_type when non-null', () async {
      String? seenSubmissionType;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_queue_get': (Map<String, dynamic> body) {
          seenSubmissionType = body['p_submission_type'] as String?;
          return ok(<String, dynamic>{
            'submissions': <dynamic>[],
            'total_count': 0,
          });
        },
      });

      await source.getReviewQueue(
        submissionType: 'trade_proof',
        limit: 50,
        offset: 0,
      );

      expect(seenSubmissionType, 'trade_proof');
    });

    test('omits p_submission_type when null', () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_queue_get': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'submissions': <dynamic>[],
            'total_count': 0,
          });
        },
      });

      await source.getReviewQueue(limit: 50, offset: 0);

      expect(seenParams!.containsKey('p_submission_type'), isFalse);
    });

    test('returns empty list when submissions is missing', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_queue_get': (_) => ok(<String, dynamic>{
              'total_count': 0,
            }),
      });

      final List<AdminReviewQueueEntryDto> entries =
          await source.getReviewQueue(limit: 20, offset: 0);

      expect(entries, isEmpty);
    });

    test('maps null optional fields gracefully', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_queue_get': (_) => ok(<String, dynamic>{
              'submissions': <dynamic>[
                queueEntryData(
                  entityLegalName: null,
                  entityAvatarPath: null,
                  documentPath: null,
                  professionId: null,
                  professionName: null,
                  assignedReviewer: null,
                  decisionNotes: null,
                ),
              ],
              'total_count': 1,
            }),
      });

      final List<AdminReviewQueueEntryDto> entries =
          await source.getReviewQueue(limit: 20, offset: 0);

      expect(entries, hasLength(1));
      expect(entries.first.entityLegalName, isNull);
      expect(entries.first.entityAvatarPath, isNull);
      expect(entries.first.documentPath, isNull);
      expect(entries.first.professionId, isNull);
      expect(entries.first.professionName, isNull);
      expect(entries.first.assignedReviewer, isNull);
      expect(entries.first.decisionNotes, isNull);
    });
  });

  group('getAuditTrail — canonical envelope', () {
    test('parses the data.audit_entries array into DTOs', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_audit_get': (_) => ok(<String, dynamic>{
              'audit_entries': <dynamic>[
                auditEntryData(),
                auditEntryData(
                  id: 'aabbccdd-0000-0000-0000-000000000002',
                  eventType: 'submission_assigned',
                  fromState: 'pending',
                  toState: 'in_review',
                  details: <String, dynamic>{
                    'submission_type': 'trade_proof',
                  },
                ),
              ],
            }),
      });

      final List<AdminReviewAuditEntryDto> entries =
          await source.getAuditTrail('ffffffff-0000-0000-0000-000000000073');

      expect(entries, hasLength(2));

      final AdminReviewAuditEntryDto first = entries.first;
      expect(first.id, 'aabbccdd-0000-0000-0000-000000000001');
      expect(first.eventType, 'submitted');
      expect(first.subjectType, 'submission');
      expect(first.subjectId, 'ffffffff-0000-0000-0000-000000000073');
      expect(first.fromState, isNull);
      expect(first.toState, 'pending');
      expect(first.actorId, '22222222-2222-2222-2222-222222222222');
      expect(first.detailsJson, isNull);

      final AdminReviewAuditEntryDto second = entries[1];
      expect(second.eventType, 'submission_assigned');
      expect(second.fromState, 'pending');
      expect(second.toState, 'in_review');
      expect(second.detailsJson, <String, dynamic>{
        'submission_type': 'trade_proof',
      });
    });

    test('returns empty list when audit_entries is missing', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_audit_get': (_) => ok(<String, dynamic>{}),
      });

      final List<AdminReviewAuditEntryDto> entries =
          await source.getAuditTrail('ffffffff-0000-0000-0000-000000000073');

      expect(entries, isEmpty);
    });
  });

  group('checkAdmin — canonical envelope', () {
    test('parses data.is_admin true', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'platform_admin_check': (_) => ok(<String, dynamic>{
              'is_admin': true,
            }),
      });

      final AdminCheckResultDto result = await source.checkAdmin();

      expect(result.isPlatformAdmin, isTrue);
    });

    test('parses data.is_admin false', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'platform_admin_check': (_) => ok(<String, dynamic>{
              'is_admin': false,
            }),
      });

      final AdminCheckResultDto result = await source.checkAdmin();

      expect(result.isPlatformAdmin, isFalse);
    });

    test('defaults to false when is_admin is missing', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'platform_admin_check': (_) => ok(<String, dynamic>{}),
      });

      final AdminCheckResultDto result = await source.checkAdmin();

      expect(result.isPlatformAdmin, isFalse);
    });

    test('maps PLT002 to a forbidden ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'platform_admin_check': (_) => <String, dynamic>{
              'code': 'PLT002',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.checkAdmin(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.forbidden)
            .having((ApiException e) => e.code, 'code', 'PLT002')),
      );
    });
  });

  group('error envelopes', () {
    test('maps PLT003 to a validation ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_queue_get': (_) => <String, dynamic>{
              'code': 'PLT003',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.getReviewQueue(limit: 20, offset: 0),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)
            .having((ApiException e) => e.code, 'code', 'PLT003')),
      );
    });

    test('maps unknown codes to a server ApiException', () {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'verification_review_audit_get': (_) => <String, dynamic>{
              'code': 'PLT999',
              'data': <String, dynamic>{},
            },
      });

      expect(
        () => source.getAuditTrail('00000000-0000-0000-0000-000000000000'),
        throwsA(isA<ApiException>()
            .having(
                (ApiException e) => e.kind, 'kind', ApiExceptionKind.server)
            .having((ApiException e) => e.code, 'code', 'PLT999')),
      );
    });
  });
}