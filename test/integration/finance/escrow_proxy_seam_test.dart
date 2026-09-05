import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/escrow_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/datasources/remote/supabase_escrow_remote_data_source.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/repositories/escrow_repository_impl.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

/// Escrow fake-E2E seam test (TT-14): the REAL datasource + repository run the
/// read lifecycle and the write-seam guard against a scripted Supabase
/// transport. Only the transport (RPC handlers) is scripted; no
/// repository/datasource logic beyond the proxy stand-in is faked.
///
/// Flow: `getByProject('project-x')` → `financial_escrow_get → {escrow,`,
/// `milestones}` → `select(escrow.id)` → `completeMilestone(...)` throws
/// `EscrowWriteUnavailableException` (guard proof) → with `writeViaProxy=true`
/// the proxy path runs (fake EP-02-18 response) → re-read `getById` shows the
/// milestone `completed`. No `supabase start` container needed (live `supabase
/// db test` is the RLS source of truth).
void main() {
  late List<Map<String, dynamic>> milestoneRows;

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  Map<String, dynamic> escrowRow() => <String, dynamic>{
        'id': 'escrow-1',
        'financial_profile_id': 'p1',
        'payer_entity_id': 'u1',
        'payee_entity_id': 'u2',
        'currency_code': 'NGN',
        'total_amount': 150000.0,
        'released_amount': 0.0,
        'refunded_amount': 0.0,
        'status': 'funded',
        'external_reference': 'order-9f9f9f9f9f9f',
        'created_at': '2026-01-01T00:00:00.000Z',
        'funded_at': '2026-01-02T00:00:00.000Z',
        'released_at': null,
        'refunded_at': null,
      };

  Map<String, dynamic> envelope() => ok(<String, dynamic>{
        'escrow': escrowRow(),
        'milestones': milestoneRows,
        'transactions': <dynamic>[],
      });

  SupabaseEscrowRemoteDataSource realDataSource({required bool writeViaProxy}) {
    return SupabaseEscrowRemoteDataSource(
      dio: Dio(),
      supabase: MockSupabaseClientFactory.create(
        currentUser: fakeUser('u1'),
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'financial_escrow_get': (_) => envelope(),
        },
      ),
      exceptionMapper: const ApiExceptionMapper(),
      writeViaProxy: writeViaProxy,
    );
  }

  setUp(() {
    milestoneRows = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'ms-1',
        'escrow_id': 'escrow-1',
        'milestone_number': 1,
        'title': 'Design approval',
        'amount': 50000.0,
        'status': 'pending',
        'sort_order': 1,
        'created_at': '2026-01-01T00:00:00.000Z',
        'completed_at': null,
        'released_at': null,
      },
      <String, dynamic>{
        'id': 'ms-2',
        'escrow_id': 'escrow-1',
        'milestone_number': 2,
        'title': 'Final delivery',
        'amount': 100000.0,
        'status': 'pending',
        'sort_order': 2,
        'created_at': '2026-01-01T00:00:00.000Z',
        'completed_at': null,
        'released_at': null,
      },
    ];
  });

  group('read lifecycle with the proxy seam off (writeViaProxy=false)', () {
    late EscrowRepositoryImpl repository;

    setUp(() {
      repository =
          EscrowRepositoryImpl(remote: realDataSource(writeViaProxy: false));
    });

    test('getByProject enumerates the scripted escrow then renders milestones',
        () async {
      // getByProject('project-x') → financial_escrow_get per known id.
      final List<Escrow> escrows = await repository.getByProject(
        projectId: 'project-x',
        escrowIds: <String>['escrow-1'],
      );
      expect(escrows, hasLength(1));
      final Escrow escrow = escrows.single;
      expect(escrow.id, 'escrow-1');
      expect(escrow.status, 'funded');
      expect(escrow.currencyCode, 'NGN');
      expect(escrow.totalAmount, 150000.0);
      expect(escrow.heldAmount, 150000.0);
      expect(escrow.isActive, isTrue);
      expect(escrow.isDisputed, isFalse);

      // select(escrow.id): milestones rendered from the envelope.
      final EscrowDetail detail = await repository.getById(escrow.id);
      expect(detail.escrow.id, escrow.id);
      expect(detail.milestones, hasLength(2));
      expect(detail.milestones.map((m) => m.status), <String>[
        'pending',
        'pending',
      ]);
      expect(detail.milestones.map((m) => m.title), <String>[
        'Design approval',
        'Final delivery',
      ]);
      expect(detail.milestonesTotal, 150000.0);
      expect(detail.transactions, isEmpty);

      // The seam flag is visible to the caller.
      expect(repository.writeAvailable, isFalse);
    });

    test('completeMilestone throws the support-team guard, never a silent no-op',
        () async {
      await expectLater(
        repository.completeMilestone(
          escrowId: 'escrow-1',
          milestoneId: 'ms-1',
        ),
        throwsA(
          isA<EscrowWriteUnavailableException>().having(
            (Object? e) => (e as EscrowWriteUnavailableException).message,
            'message',
            contains('support team'),
          ),
        ),
      );

      // The guard never touched the server state.
      final EscrowDetail detail = await repository.getById('escrow-1');
      expect(detail.milestones.first.status, 'pending');
    });
  });

  group('proxy handoff with the seam on (writeViaProxy=true)', () {
    test('the real datasource routes to the proxy branch, never a direct RPC',
        () async {
      final SupabaseEscrowRemoteDataSource on =
          realDataSource(writeViaProxy: true);
      expect(on.writeViaProxy, isTrue);

      await expectLater(
        on.completeMilestone(escrowId: 'escrow-1', milestoneId: 'ms-1'),
        throwsA(
          isA<UnimplementedError>().having(
            (Object? e) => (e as UnimplementedError).message ?? '',
            'message',
            contains('EP-02-18'),
          ),
        ),
      );
    });

    test('completeMilestone proxies, then re-reads the completed milestone',
        () async {
      // The real data source is used for every read; the proxy stand-in
      // simulates only EP-02-18's missing HTTP success response by mutating the
      // scripted server state the RPC handler serves.
      final _FakeProxyRemoteDataSource proxy =
          _FakeProxyRemoteDataSource(
        reads: realDataSource(writeViaProxy: false),
        milestoneRows: milestoneRows,
      );
      final EscrowRepositoryImpl repository = EscrowRepositoryImpl(remote: proxy);
      expect(repository.writeAvailable, isTrue);

      final EscrowDetail completed =
          await repository.completeMilestone(
            escrowId: 'escrow-1',
            milestoneId: 'ms-1',
          );

      // Re-read after the proxy call: server-authoritative state.
      expect(completed.milestones, hasLength(2));
      expect(completed.milestones.first.id, 'ms-1');
      expect(completed.milestones.first.isCompleted, isTrue);
      expect(completed.milestones.first.status, 'completed');
      expect(completed.milestones.last.status, 'pending');
      expect(completed.milestonesTotal, 150000.0);
    });
  });
}

/// Stand-in for EP-02-18's `financial-escrow-proxy` Edge Function response.
///
/// Simulates the missing proxy's success side-effect (the server flipping a
/// milestone to `completed` under `service_role`); every read is delegated to a
/// real data source so the repository's post-success re-read exercises the
/// genuine `financial_escrow_get` RPC + envelope path.
class _FakeProxyRemoteDataSource implements EscrowRemoteDataSource {
  _FakeProxyRemoteDataSource({
    required this.reads,
    required this.milestoneRows,
  });

  final EscrowRemoteDataSource reads;
  final List<Map<String, dynamic>> milestoneRows;

  @override
  bool get writeViaProxy => true;

  @override
  Future<EscrowDetailDto> getById(String id) => reads.getById(id);

  @override
  Future<List<EscrowDto>> getByProject(List<String> escrowIds) =>
      reads.getByProject(escrowIds);

  @override
  Future<String> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    throw UnimplementedError('createEscrow is not exercised by the seam test.');
  }

  @override
  Future<void> fundEscrow({required String escrowId}) async {
    throw UnimplementedError('fundEscrow is not exercised by the seam test.');
  }

  @override
  Future<void> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    for (final Map<String, dynamic> milestone in milestoneRows) {
      if (milestone['id'] == milestoneId) {
        milestone['status'] = 'completed';
        milestone['completed_at'] = '2026-01-03T00:00:00.000Z';
      }
    }
  }

  @override
  Future<void> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    throw UnimplementedError(
      'releaseMilestone is not exercised by the seam test.',
    );
  }

  @override
  Future<void> releaseFinal({required String escrowId}) async {
    throw UnimplementedError(
      'releaseFinal is not exercised by the seam test.',
    );
  }

  @override
  Future<void> refundEscrow({
    required String escrowId,
    required String reason,
  }) async {
    throw UnimplementedError('refundEscrow is not exercised by the seam test.');
  }
}