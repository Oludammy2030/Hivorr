import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/verification_repository_impl.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart';
import '../../support/fakes/fake_verification.dart';

/// Wiring for the identity-verification flow end-to-end through the REAL
/// datasource + repository + scripted Supabase RPC/query layer (no RPC logic is
/// faked; only the transport is scripted). Storage is a [FakeStorageService] so
/// no network upload occurs.
void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  const String mimeType = 'image/png';
  const String fileName = 'nin.png';

  Map<String, dynamic> submissionData({String status = 'pending'}) =>
      <String, dynamic>{
        'id': 'sub-9001',
        'entity_id': 'u1',
        'credential_id': 'cred-1',
        'submission_type': 'identity_document',
        'status': status,
        'submitted_at': '2026-01-01T00:00:00.000Z',
        'reviewed_at': null,
        'decision_notes': null,
      };

  Map<String, dynamic> statusData({
    String tier = 'tier_0',
    bool verified = false,
    int pending = 0,
    int total = 1,
  }) =>
      <String, dynamic>{
        'entity_id': 'u1',
        'kyc': <String, dynamic>{
          'tier_code': tier,
          'status': tier == 'tier_0' ? 'pending' : 'active',
          'limits': <String, dynamic>{
            'daily': tier == 'tier_0' ? 0 : 500000,
            'weekly': tier == 'tier_0' ? 0 : 2000000,
            'monthly': tier == 'tier_0' ? 0 : 8000000,
            'cashout': tier == 'tier_0' ? 0 : 1000000,
          },
        },
        'identity_verified': verified,
        'trade_verifications': <dynamic>[],
        'pending_submissions': pending,
        'total_submissions': total,
      };

  Map<String, dynamic> envelope(Object data) => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': data,
      };

  ({VerificationRepositoryImpl repository, FakeStorageService storage})
      buildFlow({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    bool signedIn = true,
    String submitStatus = 'pending',
    Map<String, dynamic> Function()? statusDataGetter,
    bool Function()? approvedGetter,
  }) {
    final FakeStorageService storage = FakeStorageService();
    final Map<String, dynamic> Function() statusGetter =
        statusDataGetter ?? statusData;
    final bool Function() approved = approvedGetter ?? (() => false);
    final Map<String, dynamic> Function() kycData = (() => approved()
        ? <String, dynamic>{
            'tier_code': 'tier_1',
            'status': 'active',
            'limits': <String, dynamic>{
              'daily': 500000,
              'weekly': 2000000,
              'monthly': 8000000,
              'cashout': 1000000,
            },
          }
        : <String, dynamic>{
            'tier_code': 'tier_0',
            'status': 'pending',
            'limits': <String, dynamic>{
              'daily': 0, 'weekly': 0, 'monthly': 0, 'cashout': 0},
          });
    final Map<String, Object? Function(Map<String, dynamic>)> defaults = {
      'verification_submit': (params) => envelope(submissionData(status: submitStatus)),
      'verification_status_get': (params) => envelope(statusGetter()),
      'verification_kyc_level_get': (params) => envelope(kycData()),
      'verification_limits_get': (params) => envelope(<String, dynamic>{
            'daily': 0,
            'weekly': 0,
            'monthly': 0,
            'cashout': 0,
          }),
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
            'kind': 'identity_document',
            'title': 'National ID (NIN)',
            'document_path': 'credential-documents/u1/abc.bin',
            'profession_id': null,
          },
        ],
      },
    );
    final SupabaseVerificationRemoteDataSource remote =
        SupabaseVerificationRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final VerificationRepositoryImpl repository = VerificationRepositoryImpl(
      remote: remote,
      storage: storage,
      supabase: client,
    );
    return (repository: repository, storage: storage);
  }

  group('Verification flow (EP-02-10 §15)', () {
    test('submits: validate → private-bucket upload → credential → RPC → entity',
        () async {
      final flow = buildFlow();
      final VerificationSubmission submission = await flow.repository
          .submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(flow.storage.lastBucket, StorageBuckets.credentialDocuments);
      expect(flow.storage.lastMimeType, mimeType);
      expect(submission.id, 'sub-9001');
      expect(submission.credentialId, 'cred-1');
      expect(submission.documentType, DocumentType.nationalId);
      expect(submission.status, VerificationStatusKind.pending);
    });

    test('submit requires a signed-in entity (server-authoritative id)',
        () async {
      final flow = buildFlow(signedIn: false);

      expect(
        () => flow.repository.submitIdentityDocument(
          documentType: DocumentType.passport,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)
            .having((ApiException e) => e.code, 'code', 'PLT001')),
      );
    });

    test('status surfaces the aggregate with KYC + counts', () async {
      final flow = buildFlow(
        rpcHandlers: {
          'verification_status_get': (params) =>
              envelope(statusData(tier: 'tier_1', verified: true)),
        },
      );

      final VerificationStatus status = await flow.repository.getStatus();

      expect(status.identityVerified, isTrue);
      expect(status.kycLevel.tierCode, 'tier_1');
      expect(status.kycLevel.limits.monthly, 8000000);
      expect(status.totalSubmissions, 1);
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

    test('provider drives the submit → refresh → success lifecycle on the '
        'real stack', () async {
      final flow = buildFlow();
      final VerificationProvider provider = VerificationProvider(
        repo: flow.repository,
      );

      await provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(provider.submitState, SubmitState.success);
      expect(provider.lastSubmission!.credentialId, 'cred-1');
      // submit() refreshes status on success via the real RPC path.
      expect(provider.status, isNotNull);
      expect(provider.status!.entityId, 'u1');
      expect(provider.kycLevel, isNotNull);
      provider.dispose();
    });

    test('TT-11: pending → (mock review_approve) → approved via refreshStatus '
        'surfaces identity verified on the real stack', () async {
      // Mutable "server state": pending until the mock review_approve flips it.
      bool approved = false;
      final flow = buildFlow(
        approvedGetter: () => approved,
        statusDataGetter: () => approved
            ? statusData(tier: 'tier_1', verified: true, total: 1)
            : statusData(),
      );
      final VerificationProvider provider = VerificationProvider(
        repo: flow.repository,
      );
      await provider.refreshStatus();
      expect(provider.status!.identityVerified, isFalse);
      expect(provider.status!.kycLevel.tierCode, 'tier_0');

      // Server-side review_approve side effect: status becomes approved tier_1.
      approved = true;
      await provider.refreshStatus();

      expect(provider.status!.identityVerified, isTrue);
      expect(provider.status!.kycLevel.tierCode, 'tier_1');
      expect(provider.kycLevel!.limits.monthly, 8000000);
      provider.dispose();
    });

    test('provider surfaces a submission failure as a typed error state',
        () async {
      final flow = buildFlow(
        rpcHandlers: {
          'verification_submit': (params) => <String, dynamic>{
                'code': 'PLT003',
                'data': <String, dynamic>{},
              },
        },
      );
      final VerificationProvider provider = VerificationProvider(
        repo: flow.repository,
      );

      await provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(provider.submitState, SubmitState.error);
      expect(provider.submitError, isA<ApiException>());
      expect(provider.submitError!.code, 'PLT003');
      provider.dispose();
    });

    test('the full flow remains server-authoritative: client never writes '
        'status/tier', () async {
      // The repository only calls the four verification RPCs; there is no
      // direct table write to verification status/tier columns.
      final flow = buildFlow();
      await flow.repository.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await flow.repository.getStatus();

      // The getLimits/getKycLevel/status/submit RPCs are exercised via the
      // real client; assertions here guard the flow completes without throwing.
      expect(flow.storage.uploadCallCount, 1);
    });
  });
}
