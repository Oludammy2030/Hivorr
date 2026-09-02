import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/datasources/remote/supabase_trade_verification_remote_data_source.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/data/repositories/trade_verification_repository_impl.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart';
import '../../support/fakes/fake_verification.dart' show FakeStorageService;

/// Wiring for the trade-verification flow end-to-end through the REAL
/// datasource + repository + scripted Supabase RPC/query layer (no RPC logic is
/// faked; only the transport is scripted). Storage is a [FakeStorageService] so
/// no network upload occurs.
void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  const String mimeType = 'application/pdf';
  const String fileName = 'proof.pdf';
  const String professionId = 'p1';

  Map<String, dynamic> submissionData({String status = 'pending'}) =>
      <String, dynamic>{
        'id': 'trade-sub-9001',
        'entity_id': 'u1',
        'credential_id': 'cred-1',
        'submission_type': 'trade_proof',
        'status': status,
        'submitted_at': '2026-01-01T00:00:00.000Z',
        'reviewed_at': null,
        'decision_notes': null,
      };

  Map<String, dynamic> statusData({String tradeStatus = 'unverified'}) =>
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
        'identity_verified': false,
        'trade_verifications': <dynamic>[
          <String, dynamic>{
            'profession_id': professionId,
            'trade_verification_status': tradeStatus,
          },
        ],
        'pending_submissions': tradeStatus == 'pending' ? 1 : 0,
        'total_submissions': tradeStatus == 'unverified' ? 0 : 1,
      };

  Map<String, dynamic> envelope(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  ({TradeVerificationRepositoryImpl repository, FakeStorageService storage})
      buildFlow({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    bool signedIn = true,
    String Function()? tradeStatusGetter,
  }) {
    final FakeStorageService storage = FakeStorageService();
    final String Function() tradeStatus = tradeStatusGetter ?? (() => 'pending');
    final Map<String, Object? Function(Map<String, dynamic>)> defaults = {
      'verification_submit': (params) =>
          envelope(submissionData(status: 'pending')),
      'verification_status_get': (params) =>
          envelope(statusData(tradeStatus: tradeStatus())),
    };
    defaults.addAll(rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{});
    final client = MockSupabaseClientFactory.create(
      currentUser: signedIn ? fakeUser('u1') : null,
      rpcHandlers: defaults,
      queryResults: <String, List<Map<String, dynamic>>>{
        'entity_credentials': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cred-1',
            'entity_id': 'u1',
            'kind': TradeProofType.tradeKind,
            'title': 'Profession p1 — Certificate',
            'document_path': 'credential-documents/u1/abc.bin',
            'profession_id': professionId,
          },
        ],
      },
    );
    final SupabaseTradeVerificationRemoteDataSource remote =
        SupabaseTradeVerificationRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final TradeVerificationRepositoryImpl repository =
        TradeVerificationRepositoryImpl(
      remote: remote,
      storage: storage,
      supabase: client,
    );
    return (repository: repository, storage: storage);
  }

  group('Trade verification flow (EP-02-11 §15)', () {
    test('submits: validate → private-bucket upload → credential → RPC → entity',
        () async {
      final flow = buildFlow();
      final VerificationSubmission submission = await flow.repository
          .submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(flow.storage.lastBucket, StorageBuckets.credentialDocuments);
      expect(flow.storage.lastMimeType, mimeType);
      expect(submission.id, 'trade-sub-9001');
      expect(submission.credentialId, 'cred-1');
      expect(submission.status, VerificationStatusKind.pending);
    });

    test('submit requires a signed-in entity (server-authoritative id)',
        () async {
      final flow = buildFlow(signedIn: false);

      expect(
        () => flow.repository.submitTradeProof(
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

    test('status surfaces the per-profession trade aggregate', () async {
      final flow = buildFlow(tradeStatusGetter: () => 'approved');

      final TradeVerificationStatus status = await flow.repository.getStatus();

      expect(status.kindFor(professionId), TradeVerificationStatusKind.approved);
    });

    test('a rejected envelope maps to a typed conflict ApiException',
        () async {
      final flow = buildFlow(
        rpcHandlers: {
          'verification_status_get': (params) => <String, dynamic>{
                'code': 'PLT005',
                'data': <String, dynamic>{},
              },
        },
      );

      expect(
        () => flow.repository.getStatus(),
        throwsA(isA<ApiException>().having((ApiException e) => e.kind,
            'kind', ApiExceptionKind.conflict)),
      );
    });

    test('provider drives submit → refresh → success on the real stack',
        () async {
      final flow = buildFlow();
      final TradeVerificationProvider provider = TradeVerificationProvider(
        repo: flow.repository,
      );

      await provider.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(provider.submitState, SubmitState.success);
      expect(provider.status, isNotNull);
      expect(provider.status!.kindFor(professionId),
          TradeVerificationStatusKind.pending);
      provider.dispose();
    });

    test('pending → (mock review_approve) → approved via refreshStatus on the '
        'real stack', () async {
      // Mutable "server state": pending until the mock review_approve flips it.
      String tradeStatus = 'pending';
      final flow = buildFlow(tradeStatusGetter: () => tradeStatus);
      final TradeVerificationProvider provider = TradeVerificationProvider(
        repo: flow.repository,
      );
      await provider.refreshStatus();
      expect(provider.status!.kindFor(professionId),
          TradeVerificationStatusKind.pending);

      // Server-side review_approve side effect: status becomes approved.
      tradeStatus = 'approved';
      await provider.refreshStatus();

      expect(provider.status!.kindFor(professionId),
          TradeVerificationStatusKind.approved);
      provider.dispose();
    });

    test('the full flow remains server-authoritative: client never writes '
        'status', () async {
      final flow = buildFlow();
      await flow.repository.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await flow.repository.getStatus();

      expect(flow.storage.uploadCallCount, 1);
    });
  });
}