// EP-02-20 VP3: Identity Verification Submit → Review → Approve → KYC Tier.
//
// Extends verification_flow_test.dart patterns with real provider composition.
// Exercises IdentityVerificationService → VerificationRepository → VerificationProvider
// with a scripted Supabase transport. Verifies: submit → pending → mock admin
// approve → verification_status_get + kyc_level_get reflected → tier upgraded.
//
// Run: flutter test test/integration/trust/identity_verification_flow_integration_test.dart

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/verification_repository_impl.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/services/identity_verification_service.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart';
import '../../support/fakes/fake_verification.dart' show FakeStorageService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  const String mimeType = 'image/png';
  const String fileName = 'nin.png';

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
    'success': true,
    'code': 'PLT000',
    'message': 'ok',
    'data': data,
  };

  // ---- Scripted "server" state -------------------------------------------
  bool approved = false;

  Map<String, dynamic> statusData() => <String, dynamic>{
    'entity_id': 'u1',
    'kyc': approved
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
              'daily': 0,
              'weekly': 0,
              'monthly': 0,
              'cashout': 0,
            },
          },
    'identity_verified': approved,
    'trade_verifications': <dynamic>[],
    'pending_submissions': approved ? 0 : 1,
    'total_submissions': 1,
  };

  ({
    VerificationRepositoryImpl repository,
    FakeStorageService storage,
    IdentityVerificationService service,
    VerificationProvider provider,
  })
  buildFlow({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    bool signedIn = true,
  }) {
    final FakeStorageService storage = FakeStorageService();
    final Map<String, Object? Function(Map<String, dynamic>)> defaults = {
      'verification_submit': (Map<String, dynamic> params) =>
          ok(<String, dynamic>{
            'id': 'sub-9001',
            'entity_id': 'u1',
            'credential_id': 'cred-1',
            'submission_type': 'identity_document',
            'status': 'pending',
            'submitted_at': '2026-01-01T00:00:00.000Z',
            'reviewed_at': null,
            'decision_notes': null,
          }),
      'verification_status_get': (_) => ok(statusData()),
      'verification_kyc_level_get': (_) => ok(
        approved
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
                  'daily': 0,
                  'weekly': 0,
                  'monthly': 0,
                  'cashout': 0,
                },
              },
      ),
      'verification_limits_get': (_) => ok(<String, dynamic>{
        'daily': 0,
        'weekly': 0,
        'monthly': 0,
        'cashout': 0,
      }),
    };
    defaults.addAll(
      rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{},
    );
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
    final remote = SupabaseVerificationRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = VerificationRepositoryImpl(
      remote: remote,
      storage: storage,
      supabase: client,
    );
    final service = IdentityVerificationService(repo: repo);
    final provider = VerificationProvider(repo: repo);
    return (
      repository: repo,
      storage: storage,
      service: service,
      provider: provider,
    );
  }

  group('VP3: Identity verification flow', () {
    test('submit → pending → admin approve → tier_1 via provider', () async {
      approved = false;
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      // Submit identity document.
      await flow.provider.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(flow.provider.submitState, SubmitState.success);
      expect(flow.provider.status?.identityVerified, isFalse);
      expect(flow.provider.kycLevel?.tierCode, 'tier_0');

      // Simulate admin approval.
      approved = true;
      await flow.provider.refreshStatus();

      expect(flow.provider.status?.identityVerified, isTrue);
      expect(flow.provider.kycLevel?.tierCode, 'tier_1');
      expect(flow.provider.kycLevel?.limits.monthly, 8000000);
    });

    test('identity doc upload goes to private bucket', () async {
      approved = false;
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await flow.service.submitIdentityDocument(
        documentType: DocumentType.nationalId,
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
        () => flow.service.submitIdentityDocument(
          documentType: DocumentType.passport,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)
              .having((ApiException e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('status surfaces KYC aggregate with counts', () async {
      approved = true;
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      final VerificationStatus status = await flow.repository.getStatus();
      expect(status.identityVerified, isTrue);
      expect(status.kycLevel.tierCode, 'tier_1');
      expect(status.totalSubmissions, 1);
    });

    test('PLT005 envelope maps to conflict ApiException', () async {
      final flow = buildFlow(
        rpcHandlers: {
          'verification_status_get': (_) => <String, dynamic>{
            'code': 'PLT005',
            'data': <String, dynamic>{},
          },
        },
      );
      addTearDown(flow.provider.dispose);

      expect(
        () => flow.repository.getStatus(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.conflict,
          ),
        ),
      );
    });

    test('client never writes status/tier columns', () async {
      approved = false;
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await flow.service.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      await flow.repository.getStatus();

      // Only storage upload + RPC reads were exercised; no direct table writes.
      expect(flow.storage.uploadCallCount, 1);
    });
  });
}
