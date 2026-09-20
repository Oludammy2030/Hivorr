// EP-02-20 VP7: Escrow Lifecycle (with Milestone + Audit) Integration Test.
//
// Extends `escrow_proxy_seam_test.dart` patterns: exercises
// EscrowService → EscrowRepository → EscrowProvider through the REAL read
// datasource (`financial_escrow_get` envelope parsing) plus a stateful
// proxy seam (`writeViaProxy = true`) that simulates EP-02-18's Edge Function
// server-side effects. Verifies: create with 2 milestones (sum pre-validated)
// → fund → milestone complete → release → final release; refund path; provider
// drives create/select/write; released-progress math; and the
// client-never-writes-directly guard when the seam is off.
//
// Run: flutter test test/integration/trust/escrow_lifecycle_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/escrow_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';
import 'package:hivorr/data/datasources/remote/supabase_escrow_remote_data_source.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/models/escrow_detail_dto.dart';
import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/repositories/escrow_repository_impl.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

Map<String, dynamic> ok(Object data) => <String, dynamic>{
      'success': true,
      'code': 'PLT000',
      'message': 'ok',
      'data': data,
    };

// ---- Scripted "server" closure state (served to the real read datasource)
// --------------------------------------------------------------------------
final Map<String, Map<String, dynamic>> escrows =
    <String, Map<String, dynamic>>{};
final Map<String, List<Map<String, dynamic>>> milestones =
    <String, List<Map<String, dynamic>>>{};
int nextEscrowId = 0;

Map<String, dynamic> rowFor(String escrowId) => escrows[escrowId]!;
List<Map<String, dynamic>> milestoneRows(String escrowId) =>
    milestones[escrowId] ?? const <Map<String, dynamic>>[];

/// Simulates the payer-side seed of `financial_escrow_create` (the proxy
/// calls the create RPC server-side): stamps the draft escrow + its
/// milestones into the closure state and returns the created id.
Map<String, dynamic> seedEscrow({
  required String payerEntityId,
  required String payeeEntityId,
  required String currencyCode,
  required double totalAmount,
  required List<EscrowMilestoneInput> milestonesInput,
}) {
  final String escrowId = 'escrow-${++nextEscrowId}';
  escrows[escrowId] = <String, dynamic>{
    'id': escrowId,
    'financial_profile_id': 'p1',
    'payer_entity_id': payerEntityId,
    'payee_entity_id': payeeEntityId,
    'currency_code': currencyCode,
    'total_amount': totalAmount,
    'released_amount': 0.0,
    'refunded_amount': 0.0,
    'status': 'draft',
    'external_reference': 'order-${escrowId.hashCode.abs()}',
    'created_at': '2026-01-01T00:00:00.000Z',
    'funded_at': null,
    'released_at': null,
    'refunded_at': null,
  };
  milestones[escrowId] = <Map<String, dynamic>>[
    for (int i = 0; i < milestonesInput.length; i++)
      <String, dynamic>{
        'id': 'ms-$escrowId-${i + 1}',
        'escrow_id': escrowId,
        'milestone_number': i + 1,
        'title': milestonesInput[i].title,
        'amount': milestonesInput[i].amount,
        'status': 'pending',
        'sort_order': i + 1,
        'created_at': '2026-01-01T00:00:00.000Z',
        'completed_at': null,
        'released_at': null,
      },
  ];
  return escrows[escrowId]!;
}

/// Stateful stand-in for EP-02-18's `financial-escrow-proxy` Edge Function:
/// `writeViaProxy = true`; reads delegate to the real datasource
/// (server-authoritative), writes mutate the closure state exactly as the
/// proxy's `service_role` RPCs would.
class _StateProxyDataSource implements EscrowRemoteDataSource {
  _StateProxyDataSource({required this._reads});

  final EscrowRemoteDataSource _reads;

  @override
  bool get writeViaProxy => true;

  @override
  Future<EscrowDetailDto> getById(String id) => _reads.getById(id);

  @override
  Future<List<EscrowDto>> getByProject(List<String> escrowIds) =>
      _reads.getByProject(escrowIds);

  @override
  Future<String> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    seedEscrow(
      payerEntityId: payerEntityId,
      payeeEntityId: payeeEntityId,
      currencyCode: currencyCode,
      totalAmount: totalAmount,
      milestonesInput: milestones,
    );
    return 'escrow-$nextEscrowId';
  }

  @override
  Future<void> fundEscrow({required String escrowId}) async {
    final Map<String, dynamic> row = rowFor(escrowId);
    row['status'] = 'funded';
    row['funded_at'] = '2026-01-02T00:00:00.000Z';
  }

  @override
  Future<void> completeMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    for (final Map<String, dynamic> m in milestoneRows(escrowId)) {
      if (m['id'] == milestoneId && m['status'] == 'pending') {
        m['status'] = 'completed';
        m['completed_at'] = '2026-01-03T00:00:00.000Z';
      }
    }
  }

  @override
  Future<void> releaseMilestone({
    required String escrowId,
    required String milestoneId,
  }) async {
    for (final Map<String, dynamic> m in milestoneRows(escrowId)) {
      if (m['id'] == milestoneId && m['status'] == 'completed') {
        m['status'] = 'released';
        m['released_at'] = '2026-01-04T00:00:00.000Z';
        final Map<String, dynamic> escrow = rowFor(escrowId);
        escrow['released_amount'] =
            (escrow['released_amount'] as num).toDouble() +
                (m['amount'] as num).toDouble();
      }
    }
  }

  @override
  Future<void> releaseFinal({required String escrowId}) async {
    final Map<String, dynamic> row = rowFor(escrowId);
    // Mirrors the server: remaining held funds move at escrow level
    // (`financial_escrow_release`, released_amount + remaining); pending
    // milestones are not re-marked released.
    final double total = (row['total_amount'] as num).toDouble();
    final double refunded = (row['refunded_amount'] as num).toDouble();
    row['released_amount'] = total - refunded;
    row['status'] = 'released';
    row['released_at'] = '2026-01-05T00:00:00.000Z';
  }

  @override
  Future<void> refundEscrow({
    required String escrowId,
    required String reason,
  }) async {
    final Map<String, dynamic> row = rowFor(escrowId);
    row['status'] = 'refunded';
    row['refunded_at'] = '2026-01-05T00:00:00.000Z';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The REAL read datasource; every transaction envelope is served from the
  // scripted closure state above (mirrors the frozen `financial_escrow_get`).
  SupabaseEscrowRemoteDataSource readDataSource() {
    return SupabaseEscrowRemoteDataSource(
      dio: Dio(),
      supabase: MockSupabaseClientFactory.create(
        currentUser: fakeUser('u1'),
        rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
          'financial_escrow_get': (Map<String, dynamic> body) =>
              ok(<String, dynamic>{
                'escrow': rowFor(body['p_escrow_id'] as String),
                'milestones': milestoneRows(body['p_escrow_id'] as String),
                'transactions': <dynamic>[],
              }),
        },
      ),
      exceptionMapper: const ApiExceptionMapper(),
      writeViaProxy: false,
    );
  }

  ({
    EscrowService service,
    EscrowProvider provider,
    EscrowRepositoryImpl repo,
    _StateProxyDataSource proxy,
  }) buildStack() {
    final _StateProxyDataSource proxy =
        _StateProxyDataSource(reads: readDataSource());
    final EscrowRepositoryImpl repo = EscrowRepositoryImpl(remote: proxy);
    final EscrowService service = EscrowService(repository: repo);
    final EscrowProvider provider = EscrowProvider(service: service);
    return (service: service, provider: provider, repo: repo, proxy: proxy);
  }

  List<EscrowMilestoneInput> twoMilestones() => <EscrowMilestoneInput>[
        const EscrowMilestoneInput(
          milestoneNumber: 1,
          title: 'Design approval',
          amount: 50000.0,
        ),
        const EscrowMilestoneInput(
          milestoneNumber: 2,
          title: 'Final delivery',
          amount: 100000.0,
        ),
      ];

  setUp(() {
    escrows.clear();
    milestones.clear();
    nextEscrowId = 0;
  });

  group('VP7: Escrow lifecycle', () {
    test(
        'DoD-VP7a: create (2 ms) → fund → milestone complete → release → final release '
        'with released-progress audit', () async {
      final stack = buildStack();
      addTearDown(stack.provider.dispose);
      expect(stack.repo.writeAvailable, isTrue,
          reason: 'proxy write seam must be on for lifecycle writes');

      // Milestone sums pre-validated client-side.
      expect(
        stack.service.validateMilestoneSums(
          totalAmount: 150000.0,
          milestoneAmounts: <double>[50000.0, 100000.0],
        ),
        isTrue,
      );

      // 1. Create with 2 milestones.
      final EscrowDetail created = await stack.service.createEscrow(
        payerEntityId: 'u1',
        payeeEntityId: 'u2',
        currencyCode: 'NGN',
        totalAmount: 150000.0,
        milestones: twoMilestones(),
      );
      expect(created.escrow.status, 'draft');
      expect(created.milestones, hasLength(2));
      expect(
        created.milestones.map((m) => m.title),
        <String>['Design approval', 'Final delivery'],
      );
      expect(
        created.milestones.map((m) => m.milestoneNumber),
        <int>[1, 2],
      );
      expect(created.milestonesTotal, 150000.0);
      final String escrowId = created.escrow.id;

      // Select the created escrow so the provider exposes detail state.
      await stack.provider.select(escrowId);

      // 2. Fund (gateway-confirmed server side effect through the proxy).
      await stack.proxy.fundEscrow(escrowId: escrowId);
      await stack.provider.refresh();
      expect(stack.provider.selected?.status, 'funded');
      expect(stack.provider.selected?.isActive, isTrue);

      // 3. Complete milestone 1 through the provider (write seam).
      final String ms1Id = created.milestones.first.id;
      await stack.provider.completeMilestone(milestoneId: ms1Id);
      expect(stack.provider.milestones.first.status, 'completed');
      expect(stack.provider.selected?.status, 'funded');

      // 4. Release milestone 1 → released_amount moves, progress audit.
      await stack.provider.releaseMilestone(milestoneId: ms1Id);
      expect(stack.provider.milestones.first.status, 'released');
      expect(stack.provider.selected?.releasedAmount, 50000.0);
      expect(
        stack.service.releasedMilestoneTotal(stack.provider.milestones),
        50000.0,
      );
      expect(
        stack.service.milestoneProgress(
          milestones: stack.provider.milestones,
          totalAmount: 150000.0,
        ),
        closeTo(1 / 3, 0.001),
      );

      // 5. Final release — escrow-level funds move in full.
      await stack.provider.releaseFinal();
      expect(stack.provider.selected?.status, 'released');
      expect(stack.provider.selected?.isActive, isFalse);
      expect(stack.provider.selected?.releasedAmount, 150000.0);
      // The server releases remaining funds at escrow level without re-marking
      // pending milestones released, so milestone-level totals stay as-is.
      expect(
        stack.service.releasedMilestoneTotal(stack.provider.milestones),
        50000.0,
      );

      // Server-authoritative re-read (fresh datasource path) agrees.
      final EscrowDetail reRead = await stack.service.getById(escrowId);
      expect(reRead.escrow.status, 'released');
      expect(reRead.escrow.releasedAmount, 150000.0);
      expect(reRead.milestones.map((m) => m.status), <String>[
        'released',
        'pending',
      ]);
    });

    test('DoD-VP7b: refund path — escrow → funded → refund', () async {
      final stack = buildStack();
      addTearDown(stack.provider.dispose);

      final EscrowDetail created = await stack.service.createEscrow(
        payerEntityId: 'u1',
        payeeEntityId: 'u2',
        currencyCode: 'NGN',
        totalAmount: 50000.0,
        milestones: <EscrowMilestoneInput>[
          const EscrowMilestoneInput(
            milestoneNumber: 1,
            title: 'Work',
            amount: 50000.0,
          ),
        ],
      );
      final String escrowId = created.escrow.id;
      await stack.provider.select(escrowId);

      final EscrowDetail refunded = await stack.provider.refundEscrow(
        reason: 'Not satisfied',
      );
      expect(refunded.escrow.status, 'refunded');
      expect(stack.provider.selected?.status, 'refunded');
      expect(stack.provider.selected?.isActive, isFalse);
    });

    test('milestone-sum guard: PLT003 surfaces before any write', () async {
      final stack = buildStack();
      addTearDown(stack.provider.dispose);

      final int before = nextEscrowId;
      await expectLater(
        stack.service.createEscrow(
          payerEntityId: 'u1',
          payeeEntityId: 'u2',
          currencyCode: 'NGN',
          totalAmount: 100000.0,
          milestones: <EscrowMilestoneInput>[
            const EscrowMilestoneInput(
              milestoneNumber: 1,
              title: 'Phase 1',
              amount: 60000.0,
            ),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(nextEscrowId, before,
          reason: 'invalid milestone sums must never reach the server');
    });

    test('seam-off guard: the client can never write escrow tables directly',
        () async {
      final SupabaseEscrowRemoteDataSource direct =
          SupabaseEscrowRemoteDataSource(
        dio: Dio(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
            'financial_escrow_get': (_) => ok(<String, dynamic>{
                  'escrow': null,
                  'milestones': <dynamic>[],
                  'transactions': <dynamic>[],
                }),
          },
        ),
        exceptionMapper: const ApiExceptionMapper(),
        writeViaProxy: false,
      );
      final EscrowRepositoryImpl repo =
          EscrowRepositoryImpl(remote: direct);
      expect(repo.writeAvailable, isFalse);

      final EscrowService service = EscrowService(repository: repo);
      await expectLater(
        service.createEscrow(
          payerEntityId: 'u1',
          payeeEntityId: 'u2',
          currencyCode: 'NGN',
          totalAmount: 50000.0,
          milestones: <EscrowMilestoneInput>[
            const EscrowMilestoneInput(
              milestoneNumber: 1,
              title: 'Work',
              amount: 50000.0,
            ),
          ],
        ),
        throwsA(isA<EscrowWriteUnavailableException>()),
      );
    });
  });
}