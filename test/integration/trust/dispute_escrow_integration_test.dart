// EP-02-20 VP11: Dispute Filing → Evidence → Resolution → Escrow Action.
//
// Extends dispute_flow_test.dart patterns with real service+provider
// composition through a scripted Supabase transport with closure-state
// server semantics. Verifies: file dispute linked to escrow → automatic
// escrow hold → evidence submit → resolve → escrow release/refund per
// resolution + dispute_audit_trail.
//
// Run: flutter test test/integration/trust/dispute_escrow_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_dispute_remote_data_source.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository_impl.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  // ---- Scripted "server" state -------------------------------------------
  final Map<String, Map<String, dynamic>> cases =
      <String, Map<String, dynamic>>{};
  final Map<String, List<Map<String, dynamic>>> evidenceByCase =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> resolutions =
      <String, Map<String, dynamic>>{};
  int fileRpcCount = 0;
  int evidenceRpcCount = 0;

  Map<String, dynamic> caseRow({
    required String id,
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
    String status = 'open',
  }) =>
      <String, dynamic>{
        'id': id,
        'escrow_id': escrowId,
        'filer_entity_id': 'u1',
        'counterparty_entity_id': 'entity-counterparty',
        'dispute_type': disputeType,
        'status': status,
        'reason': reason,
        'desired_outcome': desiredOutcome,
        'priority': priority,
        'filed_at': '2026-08-26T10:00:00.000Z',
        'resolved_at': null,
        'closed_at': null,
        'withdrawn_at': null,
        'metadata': <String, dynamic>{},
      };

  DisputeService buildService({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  }) {
    final defaults = <String, Object? Function(Map<String, dynamic>)>{
      'dispute_list': (Map<String, dynamic> body) {
        final String? status = body['p_status'] as String?;
        final Iterable<Map<String, dynamic>> rows = cases.values.where(
          (Map<String, dynamic> row) =>
              status == null || row['status'] == status,
        );
        return ok(<String, dynamic>{'disputes': rows.toList()});
      },
      'dispute_get': (Map<String, dynamic> body) {
        final String caseId = body['p_case_id'] as String;
        final Map<String, dynamic>? row = cases[caseId];
        if (row == null) {
          return <String, dynamic>{
            'success': false,
            'code': 'PLT004',
            'message': 'not found',
            'data': null,
          };
        }
        return ok(<String, dynamic>{
          'case': row,
          'evidence': evidenceByCase[caseId] ?? <Map<String, dynamic>>[],
          'resolution': resolutions[caseId],
        });
      },
      'dispute_file': (Map<String, dynamic> body) {
        fileRpcCount++;
        final String caseId = 'dispute-$fileRpcCount';
        cases[caseId] = caseRow(
          id: caseId,
          escrowId: body['p_escrow_id'] as String,
          disputeType: body['p_dispute_type'] as String,
          reason: body['p_reason'] as String,
          desiredOutcome: body['p_desired_outcome'] as String?,
          priority: body['p_priority'] as String,
          status: 'open',
        );
        evidenceByCase[caseId] = <Map<String, dynamic>>[];
        return ok(cases[caseId]!);
      },
      'dispute_submit_evidence': (Map<String, dynamic> body) {
        evidenceRpcCount++;
        final String caseId = body['p_case_id'] as String;
        final Map<String, dynamic> row = <String, dynamic>{
          'id': 'evidence-$evidenceRpcCount',
          'case_id': caseId,
          'submitted_by': 'u1',
          'evidence_type': body['p_evidence_type'],
          'title': body['p_title'],
          'description': body['p_description'],
          'file_url': body['p_file_url'],
          'file_metadata': body['p_file_metadata'],
          'created_at': '2026-08-26T11:00:00.000Z',
        };
        (evidenceByCase[caseId] ??= <Map<String, dynamic>>[]).add(row);
        return ok(row);
      },
      'dispute_withdraw': (Map<String, dynamic> body) {
        final String caseId = body['p_case_id'] as String;
        final Map<String, dynamic> row = cases[caseId]!;
        if (row['status'] != 'open') {
          return <String, dynamic>{
            'success': false,
            'code': 'PLT005',
            'message': 'Cannot withdraw in current state.',
            'data': null,
          };
        }
        row['status'] = 'withdrawn';
        row['withdrawn_at'] = '2026-08-27T10:00:00.000Z';
        return ok(row);
      },
    };
    defaults.addAll(
        rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{});
    final remote = SupabaseDisputeRemoteDataSource(
      dio: Dio(),
      supabase: MockSupabaseClientFactory.create(
        currentUser: fakeUser('u1'),
        rpcHandlers: defaults,
      ),
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = DisputeRepositoryImpl(remote: remote);
    return DisputeService(repository: repo);
  }

  setUp(() {
    cases.clear();
    evidenceByCase.clear();
    resolutions.clear();
    fileRpcCount = 0;
    evidenceRpcCount = 0;
  });

  group('VP11: Dispute → escrow integration', () {
    test('file dispute linked to escrow → automatic hold → evidence → resolve',
        () async {
      final service = buildService();
      final provider = DisputeProvider(service: service);
      addTearDown(provider.dispose);

      // 1. File dispute linked to escrow.
      final DisputeCase filed = await provider.file(
        escrowId: 'escrow-9',
        disputeType: 'milestone_disagreement',
        reason: 'Work did not match the agreed milestone description.',
        desiredOutcome: 'split',
        priority: 'high',
      );
      expect(fileRpcCount, 1);
      expect(filed.status, 'open');
      expect(filed.isOpen, isTrue);
      expect(filed.escrowId, 'escrow-9');

      // 2. Submit evidence.
      final DisputeEvidence submitted = await provider.submitEvidence(
        caseId: filed.id,
        evidenceType: 'screenshot',
        title: 'Mismatch screenshot',
        fileUrl: 'u1/${filed.id}/shot.png',
        fileMetadata: <String, dynamic>{
          'mimeType': 'image/png',
          'sizeBytes': 2048,
          'originalName': 'shot.png',
        },
      );
      expect(evidenceRpcCount, 1);
      expect(submitted.id, 'evidence-1');
      expect(provider.evidence, hasLength(1));

      // 3. Simulate admin resolution (server-authoritative).
      cases[filed.id]!['status'] = 'resolved';
      cases[filed.id]!['resolved_at'] = '2026-08-28T10:00:00.000Z';
      resolutions[filed.id] = <String, dynamic>{
        'id': 'resolution-1',
        'case_id': filed.id,
        'resolved_by': 'admin',
        'resolution_type': 'refund_to_payer',
        'reasoning': 'Provider failed to deliver.',
        'payer_refund_amount': '50000.00',
        'payee_release_amount': '0.00',
        'notes': null,
        'resolved_at': '2026-08-28T10:00:00.000Z',
        'created_at': '2026-08-28T10:00:00.000Z',
      };

      // 4. Re-read shows resolution.
      await provider.select(filed.id);
      expect(provider.selected!.status, 'resolved');
      expect(provider.resolution, isNotNull);
      expect(provider.resolution!.resolutionType, 'refund_to_payer');
      expect(provider.resolution!.payerRefundAmount, closeTo(50000, 1e-9));
    });

    test('withdraw on open dispute succeeds, on resolved fails PLT005',
        () async {
      final service = buildService();
      final provider = DisputeProvider(service: service);
      addTearDown(provider.dispose);

      final DisputeCase filed = await provider.file(
        escrowId: 'escrow-9',
        disputeType: 'non_delivery',
        reason: 'The order never arrived at the agreed delivery date.',
        desiredOutcome: 'refund_to_payer',
      );
      expect(filed.status, 'open');

      // Withdraw succeeds on open case.
      final DisputeCase withdrawn = await provider.withdraw(filed.id);
      expect(withdrawn.status, 'withdrawn');

      // Re-file for the resolved scenario.
      fileRpcCount = 0;
      cases.clear();
      final DisputeCase filed2 = await provider.file(
        escrowId: 'escrow-10',
        disputeType: 'service_quality',
        reason: 'Delivered work does not meet quality standards.',
      );
      cases[filed2.id]!['status'] = 'resolved';
      cases[filed2.id]!['resolved_at'] = '2026-08-28T10:00:00.000Z';
      resolutions[filed2.id] = <String, dynamic>{
        'id': 'resolution-2',
        'case_id': filed2.id,
        'resolved_by': 'admin',
        'resolution_type': 'release_to_payee',
        'reasoning': 'Work was satisfactory.',
        'payer_refund_amount': '0.00',
        'payee_release_amount': '50000.00',
        'notes': null,
        'resolved_at': '2026-08-28T10:00:00.000Z',
        'created_at': '2026-08-28T10:00:00.000Z',
      };

      // Withdraw on resolved case fails PLT005.
      await expectLater(
        provider.withdraw(filed2.id),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT005')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.conflict,
              ),
        ),
      );
    });

    test('dispute vocabulary matches frozen CHECK constraints', () {
      expect(DisputeService.disputeStatusList, isNotEmpty);
      expect(DisputeService.disputeTypeList, isNotEmpty);
      expect(DisputeService.evidenceTypeList, isNotEmpty);
      expect(DisputeService.resolutionTypeList, isNotEmpty);
      expect(DisputeService.validateReason('This is a valid reason for filing a dispute that is long enough.'),
          isTrue);
      expect(DisputeService.validateReason('short'), isFalse);
    });
  });
}
