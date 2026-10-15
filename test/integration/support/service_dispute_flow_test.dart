import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_dispute_remote_data_source.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository_impl.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

/// Service-engagement dispute fake-E2E flow (EP-03-17): the REAL
/// `SupabaseDisputeRemoteDataSource` + [DisputeRepositoryImpl] +
/// [DisputeService] + [DisputeProvider] run the whole
/// file-by-contract (contract frozen, escrow hold when funded) →
/// service re-read (joined contract summary) → evidence →
/// contract-filtered list → withdraw (both holds released) lifecycle against
/// a scripted Supabase transport with closure-state server semantics. Only
/// the RPC transport is scripted — no datasource/repository/service logic is
/// faked. `dispute_resolve` never appears.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> ok(Object? data, [String message = 'ok']) =>
      <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': message,
        'data': data,
      };

  // ---- Scripted "server" state -------------------------------------------
  final Map<String, Map<String, dynamic>> cases =
      <String, Map<String, dynamic>>{};
  final Map<String, List<Map<String, dynamic>>> evidenceByCase =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String> contractStatus = <String, String>{
    'contract-1': 'active',
  };
  final Map<String, String> escrowStatus = <String, String>{
    'escrow-9': 'funded',
  };
  int fileRpcCount = 0;
  int withdrawRpcCount = 0;

  Map<String, dynamic> caseRow({
    required String id,
    required String contractId,
    String? escrowId,
    String status = 'open',
  }) => <String, dynamic>{
    'id': id,
    'escrow_id': escrowId,
    'contract_id': contractId,
    'filer_entity_id': 'u1',
    'counterparty_entity_id': 'entity-counterparty',
    'dispute_type': 'milestone_disagreement',
    'status': status,
    'reason': 'The milestone was marked complete without delivering scope.',
    'desired_outcome': 'refund_to_payer',
    'priority': 'high',
    'filed_at': '2026-02-01T00:00:00.000Z',
    'resolved_at': null,
    'closed_at': null,
    'withdrawn_at': status == 'withdrawn' ? '2026-02-02T00:00:00.000Z' : null,
    'metadata': <String, dynamic>{'pre_dispute_status': 'active'},
  };

  Map<String, dynamic> contractJoin(String contractId) => <String, dynamic>{
    'id': contractId,
    'status': contractStatus[contractId] ?? 'active',
    'escrow_id': contractId == 'contract-1' ? 'escrow-9' : null,
    'total_amount': 20000,
    'currency_code': 'NGN',
    'service_listing_id': 'listing-1',
    'listing_title': 'Fixture service offering',
  };

  final SupabaseDisputeRemoteDataSource dataSource =
      SupabaseDisputeRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'service_dispute_file': (Map<String, dynamic> body) {
              final String contractId = body['p_contract_id'] as String;
              if ((contractStatus[contractId] ?? 'active') == 'disputed') {
                return <String, dynamic>{
                  'success': false,
                  'code': 'PLT005',
                  'message': 'Contract is not in a disputable state.',
                  'data': null,
                };
              }
              fileRpcCount++;
              final String caseId = 'dispute-service-$fileRpcCount';
              // Server-authoritative commit: freeze the contract, hold the
              // escrow when the engagement is funded.
              contractStatus[contractId] = 'disputed';
              final String? escrowId = contractId == 'contract-1'
                  ? 'escrow-9'
                  : null;
              if (escrowId != null) escrowStatus[escrowId] = 'disputed';
              cases[caseId] = caseRow(
                id: caseId,
                contractId: contractId,
                escrowId: escrowId,
              );
              evidenceByCase[caseId] = <Map<String, dynamic>>[];
              return ok(cases[caseId], 'Service dispute filed.');
            },
            'service_dispute_get': (Map<String, dynamic> body) {
              final String caseId = body['p_case_id'] as String;
              final Map<String, dynamic>? row = cases[caseId];
              if (row == null) {
                return <String, dynamic>{
                  'success': false,
                  'code': 'PLT004',
                  'message': 'Dispute case not found.',
                  'data': null,
                };
              }
              final String contractId = row['contract_id'] as String;
              return ok(<String, dynamic>{
                'case': row,
                'evidence': evidenceByCase[caseId] ?? <Map<String, dynamic>>[],
                'resolution': null,
                'contract': contractJoin(contractId),
              }, 'Service dispute retrieved.');
            },
            'service_dispute_list_for_contract':
                (Map<String, dynamic> body) {
                  final String contractId = body['p_contract_id'] as String;
                  final String? status = body['p_status'] as String?;
                  final rows = cases.values
                      .where(
                        (Map<String, dynamic> row) =>
                            row['contract_id'] == contractId &&
                            (status == null || row['status'] == status),
                      )
                      .toList();
                  return ok(<String, dynamic>{'disputes': rows},
                      'Service disputes listed.');
                },
            'dispute_submit_evidence': (Map<String, dynamic> body) {
              final String caseId = body['p_case_id'] as String;
              final Map<String, dynamic> row = <String, dynamic>{
                'id': 'evidence-service-1',
                'case_id': caseId,
                'submitted_by': 'u1',
                'evidence_type': body['p_evidence_type'],
                'title': body['p_title'],
                'description': body['p_description'],
                'file_url': body['p_file_url'],
                'file_metadata': body['p_file_metadata'],
                'created_at': '2026-02-01T01:00:00.000Z',
              };
              (evidenceByCase[caseId] ??= <Map<String, dynamic>>[]).add(row);
              return ok(row, 'Evidence submitted.');
            },
            'dispute_withdraw': (Map<String, dynamic> body) {
              final String caseId = body['p_case_id'] as String;
              final Map<String, dynamic> row = cases[caseId]!;
              if (row['status'] != 'open') {
                return <String, dynamic>{
                  'success': false,
                  'code': 'PLT005',
                  'message': 'Only an open dispute may be withdrawn.',
                  'data': null,
                };
              }
              withdrawRpcCount++;
              row['status'] = 'withdrawn';
              row['withdrawn_at'] = '2026-02-02T00:00:00.000Z';
              // Server-authoritative unfreeze of both holds.
              final String contractId = row['contract_id'] as String;
              contractStatus[contractId] = 'active';
              final String? escrowId = row['escrow_id'] as String?;
              if (escrowId != null) escrowStatus[escrowId] = 'funded';
              return ok(row, 'Dispute withdrawn.');
            },
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
      );

  final DisputeRepositoryImpl repository = DisputeRepositoryImpl(
    remote: dataSource,
  );
  final DisputeService service = DisputeService(repository: repository);
  late DisputeProvider provider;

  setUp(() {
    provider = DisputeProvider(service: service);
    cases.clear();
    evidenceByCase.clear();
    contractStatus['contract-1'] = 'active';
    escrowStatus['escrow-9'] = 'funded';
    fileRpcCount = 0;
    withdrawRpcCount = 0;
  });

  tearDown(() {
    provider.dispose();
  });

  test(
      'file-by-contract → frozen reads → evidence → filtered list → withdraw '
      'fake-E2E with server semantics', () async {
    // 1. File against the funded contract through the real RPC chain.
    final DisputeCase filed = await provider.fileForContract(
      contractId: 'contract-1',
      disputeType: 'milestone_disagreement',
      reason: 'The milestone was marked complete without delivering scope.',
      desiredOutcome: 'refund_to_payer',
      priority: 'high',
    );
    expect(fileRpcCount, 1);
    expect(filed.id, 'dispute-service-1');
    expect(filed.contractId, 'contract-1');
    expect(filed.hasContract, isTrue);
    expect(filed.hasEscrow, isTrue);

    // 2. The server froze both the contract and the escrow…
    expect(contractStatus['contract-1'], 'disputed');
    expect(escrowStatus['escrow-9'], 'disputed');

    // …and the provider selection carries the joined contract summary.
    expect(provider.selected!.id, 'dispute-service-1');
    expect(provider.contractSummary, isNotNull);
    expect(provider.contractSummary!.id, 'contract-1');
    expect(provider.contractSummary!.isDisputed, isTrue);
    expect(provider.contractSummary!.isFunded, isTrue);

    // 3. A second filing attempt is rejected while the freeze holds.
    await expectLater(
      provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'fraud',
        reason: 'A second attempt with enough text to pass validation.',
      ),
      throwsA(isA<Object>()),
    );

    // 4. Evidence appends to the selected service case.
    await provider.submitEvidence(
      caseId: 'dispute-service-1',
      evidenceType: 'document',
      title: 'Contract scope annex',
      fileUrl: 'u1/dispute/dispute-service-1/annex.pdf',
      fileMetadata: const <String, dynamic>{
        'mimeType': 'application/pdf',
        'sizeBytes': 4096,
        'originalName': 'annex.pdf',
      },
    );
    expect(provider.evidence, hasLength(1));

    // 5. The contract-filtered list reflects the single open case and never
    //    pollutes the global list scope.
    final listed = await provider.listForContract('contract-1');
    expect(listed, hasLength(1));
    expect(provider.disputes, isEmpty);

    // 6. Withdraw releases both holds and the re-read stays authoritative.
    final withdrawn = await provider.withdraw('dispute-service-1');
    expect(withdrawRpcCount, 1);
    expect(withdrawn.status, 'withdrawn');
    expect(contractStatus['contract-1'], 'active');
    expect(escrowStatus['escrow-9'], 'funded');
  });
}
