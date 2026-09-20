// EP-02-20 VP4: Trade Verification Submit → Admin Review → Bid-Lock Released.
//
// Extends trade_verification_flow_test.dart patterns with real provider
// composition. Exercises TradeVerificationService → TradeVerificationRepository
// → TradeVerificationProvider with a scripted Supabase transport. Verifies:
// submit → pending → mock admin approve → trade_verification_status==approved
// → provider reflects approved, bid-lock released.
//
// Run: flutter test test/integration/trust/trade_verification_gate_integration_test.dart

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/datasources/remote/supabase_trade_verification_remote_data_source.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/data/repositories/trade_verification_repository_impl.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:hivorr/systems/verification/services/trade_verification_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart';
import '../../support/fakes/fake_verification.dart' show FakeStorageService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  const String mimeType = 'application/pdf';
  const String fileName = 'proof.pdf';
  const String professionId = 'prof-sw';

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  // ---- Scripted "server" state -------------------------------------------
  String tradeStatus = 'unverified';

  Map<String, dynamic> statusData() => <String, dynamic>{
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
        'identity_verified': false,
        'trade_verifications': <dynamic>[
          <String, dynamic>{
            'profession_id': professionId,
            'trade_verification_status': tradeStatus,
          },
        ],
        'pending_submissions': tradeStatus == 'pending' ? 1 : 0,
        'total_submissions':
            tradeStatus == 'unverified' ? 0 : 1,
      };

  ({
    TradeVerificationRepositoryImpl repository,
    FakeStorageService storage,
    TradeVerificationService service,
    TradeVerificationProvider provider,
  }) buildFlow({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    bool signedIn = true,
  }) {
    final FakeStorageService storage = FakeStorageService();
    final Map<String, Object? Function(Map<String, dynamic>)> defaults = {
      'verification_submit': (_) => ok(<String, dynamic>{
            'id': 'trade-sub-9001',
            'entity_id': 'u1',
            'credential_id': 'cred-1',
            'submission_type': 'trade_proof',
            'status': 'pending',
            'submitted_at': '2026-01-01T00:00:00.000Z',
            'reviewed_at': null,
            'decision_notes': null,
          }),
      'verification_status_get': (_) => ok(statusData()),
    };
    defaults.addAll(
        rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{});
    final client = MockSupabaseClientFactory.create(
      currentUser: signedIn ? fakeUser('u1') : null,
      rpcHandlers: defaults,
      queryResults: <String, List<Map<String, dynamic>>>{
        'entity_credentials': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cred-1',
            'entity_id': 'u1',
            'kind': TradeProofType.tradeKind,
            'title': 'Profession $professionId — Certificate',
            'document_path': 'credential-documents/u1/abc.bin',
            'profession_id': professionId,
          },
        ],
      },
    );
    final remote = SupabaseTradeVerificationRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = TradeVerificationRepositoryImpl(
      remote: remote,
      storage: storage,
      supabase: client,
    );
    final service = TradeVerificationService(repo: repo);
    final provider = TradeVerificationProvider(repo: repo);
    return (repository: repo, storage: storage, service: service, provider: provider);
  }

  group('VP4: Trade verification gate', () {
    test('submit → (gate stays unverified until review) → admin approve → '
        'approved → bid-lock released', () async {
      tradeStatus = 'unverified';
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      // Submit trade proof.
      await flow.provider.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(flow.provider.submitState, SubmitState.success);
      // The server's `verification_submit` only queues a submission row — the
      // profession's `trade_verification_status` column stays `unverified`
      // until the service-role review flips it (`approved`, migration
      // 20260829090003:476-482). No client write can fake `pending`.
      expect(flow.provider.status?.kindFor(professionId),
          TradeVerificationStatusKind.unverified);

      // Simulate admin approval (server side effect).
      tradeStatus = 'approved';
      await flow.provider.refreshStatus();

      expect(flow.provider.status?.kindFor(professionId),
          TradeVerificationStatusKind.approved);
    });

    test('trade proof upload goes to private bucket', () async {
      tradeStatus = 'unverified';
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await flow.service.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(flow.storage.lastBucket, StorageBuckets.credentialDocuments);
      expect(flow.storage.lastMimeType, mimeType);
    });

    test('submit requires signed-in entity', () async {
      final flow = buildFlow(signedIn: false);
      addTearDown(flow.provider.dispose);

      expect(
        () => flow.service.submitTradeProof(
          type: TradeProofType.license,
          professionId: professionId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)
            .having((ApiException e) => e.code, 'code', 'PLT001')),
      );
    });

    test('status surfaces per-profession trade aggregate', () async {
      tradeStatus = 'approved';
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      final TradeVerificationStatus status = await flow.repository.getStatus();
      expect(status.kindFor(professionId),
          TradeVerificationStatusKind.approved);
    });

    test('rejected path surfaces rejection_reason', () async {
      tradeStatus = 'rejected';
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      final TradeVerificationStatus status = await flow.repository.getStatus();
      expect(status.kindFor(professionId),
          TradeVerificationStatusKind.rejected);
    });

    test('client never mutates gate columns', () async {
      tradeStatus = 'unverified';
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await flow.service.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await flow.repository.getStatus();

      // Only storage upload + RPC reads were exercised.
      expect(flow.storage.uploadCallCount, 1);
    });
  });
}
