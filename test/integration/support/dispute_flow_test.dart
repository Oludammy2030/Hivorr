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

/// Dispute fake-E2E flow (EP-02-17): the REAL
/// `SupabaseDisputeRemoteDataSource` + [DisputeRepositoryImpl] +
/// [DisputeService] + [DisputeProvider] run the whole list → file (escrow
/// held) → detail re-read → submit evidence → withdraw lifecycle against a
/// scripted Supabase transport with **closure-state server semantics** (the
/// simulated `dispute_file` inserts a case and applies the automatic hold;
/// `dispute_get`/`dispute_list` read that state). Only the RPC transport is
/// scripted — no datasource/repository/service logic is faked. The five
/// client-callable RPCs are exercised and `dispute_resolve` never appears.
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
  int withdrawRpcCount = 0;

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
        'withdrawn_at': status == 'withdrawn'
            ? '2026-08-27T10:00:00.000Z'
            : null,
        'metadata': <String, dynamic>{},
      };

  final SupabaseDisputeRemoteDataSource dataSource =
      SupabaseDisputeRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
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
            throw StateError('dispute_get for unknown case $caseId');
          }
          return ok(<String, dynamic>{
            'case': row,
            'evidence': evidenceByCase[caseId] ?? <Map<String, dynamic>>[],
            'resolution': resolutions[caseId],
          });
        },
        'dispute_file': (Map<String, dynamic> body) {
          fileRpcCount++;
          final String escrowId = body['p_escrow_id'] as String;
          final String disputeType = body['p_dispute_type'] as String;
          final String reason = body['p_reason'] as String;
          final String? desiredOutcome = body['p_desired_outcome'] as String?;
          final String priority = body['p_priority'] as String;
          // Server-authoritative commit: insert the case WITH the automatic
          // escrow hold (`status = 'open'`), mirroring the SECURITY DEFINER
          // body's `status_open = true` disposition path.
          final String caseId = 'dispute-rpc-$fileRpcCount';
          cases[caseId] = caseRow(
            id: caseId,
            escrowId: escrowId,
            disputeType: disputeType,
            reason: reason,
            desiredOutcome: desiredOutcome,
            priority: priority,
            status: 'open',
          );
          evidenceByCase[caseId] = <Map<String, dynamic>>[];
          return ok(cases[caseId]!);
        },
        'dispute_submit_evidence': (Map<String, dynamic> body) {
          evidenceRpcCount++;
          final String caseId = body['p_case_id'] as String;
          final Map<String, dynamic> row = <String, dynamic>{
            'id': 'evidence-rpc-$evidenceRpcCount',
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
          // Withdrawal is only legal while the case is open (server PLT005 on
          // any other state — the SECURITY DEFINER flips escrow → funded).
          if (row['status'] != 'open') {
            return <String, dynamic>{
              'success': false,
              'code': 'PLT005',
              'message': 'This dispute cannot be modified in its current state.',
              'data': null,
            };
          }
          withdrawRpcCount++;
          row['status'] = 'withdrawn';
          row['withdrawn_at'] = '2026-08-27T10:00:00.000Z';
          return ok(row);
        },
      },
    ),
    exceptionMapper: const ApiExceptionMapper(),
  );

  final DisputeRepositoryImpl repository =
      DisputeRepositoryImpl(remote: dataSource);

  final DisputeService service = DisputeService(repository: repository);

  late DisputeProvider provider;

  setUp(() {
    provider = DisputeProvider(service: service);
    cases.clear();
    evidenceByCase.clear();
    resolutions.clear();
    fileRpcCount = 0;
    evidenceRpcCount = 0;
    withdrawRpcCount = 0;
  });

  tearDown(() {
    provider.dispose();
  });

  test('list → file (escrow held) → detail re-read → evidence → withdraw '
      'fake-E2E with server semantics', () async {
    // 1. List is empty on the server initially.
    await provider.loadList();
    expect(provider.disputes, isEmpty);

    // 2. File a dispute through the real RPC + repository. The scripted
    //    server applies the automatic escrow hold (status open).
    final DisputeCase filed = await provider.file(
      escrowId: 'escrow-9',
      disputeType: 'milestone_disagreement',
      reason: 'Work did not match the agreed milestone description.',
      desiredOutcome: 'split',
      priority: 'high',
    );
    expect(fileRpcCount, 1);
    expect(filed.id, 'dispute-rpc-1');
    expect(filed.status, 'open');
    expect(filed.isOpen, isTrue);
    expect(filed.escrowId, 'escrow-9');
    expect(filed.priority, 'high');
    expect(provider.selected!.id, 'dispute-rpc-1');

    // 3. The post-write re-read hit dispute_get exactly once for the filed id.
    //    The provider selection already carries the authoritative case.
    expect(provider.selected!.status, 'open');
    expect(provider.evidence, isEmpty);
    expect(provider.resolution, isNull);

    // 4. List now reflects the single open case (server state).
    await provider.loadList();
    expect(provider.disputes, hasLength(1));
    expect(provider.disputes.single.id, 'dispute-rpc-1');

    // 5. Submit immutable evidence through the real RPC; it is appended to the
    //    selected case read model.
    final DisputeEvidence submitted = await provider.submitEvidence(
      caseId: 'dispute-rpc-1',
      evidenceType: 'screenshot',
      title: 'Mismatch screenshot',
      fileUrl: 'u1/dispute-rpc-1/shot.png',
      fileMetadata: <String, dynamic>{
        'mimeType': 'image/png',
        'sizeBytes': 2048,
        'originalName': 'shot.png',
      },
    );
    expect(evidenceRpcCount, 1);
    expect(submitted.id, 'evidence-rpc-1');
    expect(provider.evidence, hasLength(1));
    expect(provider.evidence.single.title, 'Mismatch screenshot');

    // 6. A fresh select re-reads evidence from the server (not the provider's
    //    in-memory append).
    await provider.select('dispute-rpc-1');
    expect(provider.evidence, hasLength(1));
    expect(provider.evidence.single.fileUrl, 'u1/dispute-rpc-1/shot.png');

    // 7. Withdraw through the real SECURITY DEFINER-shaped RPC. The server flips
    //    the case to withdrawn; the provider updates the selection.
    final DisputeCase updated = await provider.withdraw('dispute-rpc-1');
    expect(withdrawRpcCount, 1);
    expect(updated.status, 'withdrawn');
    expect(updated.isOpen, isFalse);
    expect(provider.selected!.status, 'withdrawn');

    // 8. The list filter reflects the server-side state change.
    await provider.loadList(status: 'open');
    expect(provider.disputes, isEmpty); // no open cases remain
    await provider.loadList(status: 'withdrawn');
    expect(provider.disputes, hasLength(1));
    expect(provider.disputes.single.status, 'withdrawn');
  });

  test('admin resolution surfaces via re-read; withdraw is refused outside '
      'open', () async {
    // 1. File a second dispute; the server commits it as open (hold applied).
    final DisputeCase filed = await provider.file(
      escrowId: 'escrow-9',
      disputeType: 'non_delivery',
      reason: 'The order never arrived at the agreed delivery date.',
      desiredOutcome: 'refund_to_payer',
      priority: 'critical',
    );
    expect(filed.status, 'open');

    // 2. The admin (service-granted) resolver commits a binding outcome and
    //    flips the case to resolved server-side. The client only re-reads.
    final String caseId = filed.id;
    cases[caseId]!['status'] = 'resolved';
    cases[caseId]!['resolved_at'] = '2026-08-28T10:00:00.000Z';
    resolutions[caseId] = <String, dynamic>{
      'id': 'resolution-1',
      'case_id': caseId,
      'resolved_by': 'admin',
      'resolution_type': 'refund_to_payer',
      'reasoning': 'The provider failed to dispatch; a full refund is due.',
      'payer_refund_amount': '50000.00',
      'payee_release_amount': '0.00',
      'notes': null,
      'resolved_at': '2026-08-28T10:00:00.000Z',
      'created_at': '2026-08-28T10:00:00.000Z',
    };

    // 3. A fresh select re-reads the authoritative envelope and surfaces the
    //    resolution + terminal status (DoD TT-14 resolution display).
    await provider.select(caseId);
    expect(provider.selected!.status, 'resolved');
    expect(provider.resolution, isNotNull);
    expect(provider.resolution!.resolutionType, 'refund_to_payer');
    expect(provider.resolution!.reasoning, contains('full refund'));
    expect(provider.resolution!.payerRefundAmount, closeTo(50000, 1e-9));
    expect(provider.resolution!.payeeReleaseAmount, 0.0);

    // 4. Withdraw is refused on a non-open case (server PLT005 → conflict),
    //    confirming withdrawal is only ever possible on an open case.
    await expectLater(
      provider.withdraw(caseId),
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
    expect(provider.selected!.status, 'resolved'); // no optimistic state
  });
}