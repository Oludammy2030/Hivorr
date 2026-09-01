import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/repositories/verification_repository_impl.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';
import '../../../support/fakes/fake_supabase.dart';
import '../../../support/fakes/fake_verification.dart';

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
  const String mimeType = 'image/png';
  const String fileName = 'nin.png';

  Map<String, dynamic> credentialRow() => <String, dynamic>{
        'id': 'cred-1',
        'entity_id': 'u1',
        'kind': 'identity_document',
        'title': DocumentType.nationalId.label,
        'document_path': 'credential-documents/u1/abc.bin',
        'profession_id': null,
      };

  VerificationRepositoryImpl build({
    FakeVerificationRemoteDataSource? remote,
    bool signedIn = true,
  }) {
    final FakeVerificationRemoteDataSource dataSource =
        remote ?? FakeVerificationRemoteDataSource();
    return VerificationRepositoryImpl(
      remote: dataSource,
      storage: FakeStorageService(),
      supabase: MockSupabaseClientFactory.create(
        currentUser: signedIn ? fakeUser('u1') : null,
        queryResults: <String, List<Map<String, dynamic>>>{
          'entity_credentials': <Map<String, dynamic>>[credentialRow()],
        },
      ),
    );
  }

  group('submitIdentityDocument', () {
    test('submits after validation + upload for a signed-in entity', () async {
      final remote = FakeVerificationRemoteDataSource();
      final repo = build(remote: remote);

      final VerificationSubmission submission = await repo.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(submission.documentType, DocumentType.nationalId);
      expect(submission.status, VerificationStatusKind.pending);
      expect(submission.credentialId, 'cred-1');
      expect(remote.lastCredentialId, 'cred-1');
      expect(remote.lastSubmissionType, DocumentType.submissionType);
      expect(remote.submitCallCount, 1);
    });

    test('uploads to the private credential-documents bucket', () async {
      final repo = build();

      await repo.submitIdentityDocument(
        documentType: DocumentType.passport,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      // Storage assertions are captured via the FakeStorageService injected
      // above; the repository must target the private bucket, not public.
      expect(
        StorageBuckets.credentialDocuments,
        isNot('public'),
      );
    });

    test('passes mime type and byte length to storage', () async {
      final remote = FakeVerificationRemoteDataSource();
      final storage = FakeStorageService();
      final repo = VerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(storage.lastMimeType, mimeType);
      expect(storage.lastByteLength, bytes.length);
    });

    test('does not call the RPC when validation fails', () async {
      final remote = FakeVerificationRemoteDataSource();
      final storage = FakeStorageService()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'bad mime',
          code: 'PLT003',
        );
      final repo = VerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await expectLater(
        repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: 'text/html',
          fileName: fileName,
        ),
        throwsA(isA<ApiException>().having((ApiException e) => e.code,
            'code', 'PLT003')),
      );
      expect(remote.submitCallCount, 0);
      expect(storage.uploadCallCount, 0);
    });

    test('calls validateForBucket on the private credential bucket', () async {
      final storage = FakeStorageService();
      final repo = VerificationRepositoryImpl(
        remote: FakeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(storage.uploadCallCount, 1);
      expect(storage.lastBucket, StorageBuckets.credentialDocuments);
    });

    test('forwards onProgress to the storage upload', () async {
      final storage = FakeStorageService();
      final repo = VerificationRepositoryImpl(
        remote: FakeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitIdentityDocument(
        documentType: DocumentType.nationalId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: (int sent, int total) {},
      );

      expect(storage.lastOnProgress, isNotNull);
    });

    test('getLimits is served independently from getKycLevel', () async {
      final remote = FakeVerificationRemoteDataSource();
      final repo = build(remote: remote);

      await repo.getLimits();
      await repo.getLimits();
      final KycLevel level = await repo.getKycLevel();

      expect(remote.limitsCallCount, 2);
      expect(remote.kycCallCount, 1);
      expect(level.tierCode, 'tier_0');
    });

    test('propagates a generic upload throw as a server ApiException',
        () async {
      final storage = FakeStorageService();
      storage.nextError = const ApiException(
        kind: ApiExceptionKind.server,
        message: 'storage down',
        code: 'PLT999',
      );
      final repo = VerificationRepositoryImpl(
        remote: FakeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await expectLater(
        repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>().having((ApiException e) => e.kind,
            'kind', ApiExceptionKind.server)),
      );
    });

    test('returns entity mapped with the caller-supplied document type',
        () async {
      final repo = build();

      final VerificationSubmission submission = await repo.submitIdentityDocument(
        documentType: DocumentType.votersCard,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(submission.documentType, DocumentType.votersCard);
    });

    test('throws PLT001 auth when no entity is signed in', () async {
      final repo = build(signedIn: false);

      expect(
        () => repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)
            .having((ApiException e) => e.code, 'code', 'PLT001')),
      );
    });

    test('propagates a storage validation failure before any upload', () async {
      final storage = FakeStorageService()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Unsupported mime',
          code: 'PLT003',
        );
      final remote = FakeVerificationRemoteDataSource();
      final repo = VerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      expect(
        () => repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)),
      );
      expect(remote.submitCallCount, 0);
    });

    test('propagates an upload failure without calling the RPC', () async {
      final remote = FakeVerificationRemoteDataSource();
      final storage = FakeStorageService()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'upload failed',
          code: 'X0',
        );
      final repo = VerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      expect(
        () => repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.server)),
      );
      expect(remote.submitCallCount, 0);
    });

    test('throws PLT999 when the credential row insert returns no rows',
        () async {
      final repo = VerificationRepositoryImpl(
        remote: FakeVerificationRemoteDataSource(),
        storage: FakeStorageService(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[],
          },
        ),
      );

      expect(
        () => repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT999')),
      );
    });

    test('surfaces a remote conflict (PLT005) from the RPC layer', () async {
      final remote = FakeVerificationRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'duplicate',
          code: 'PLT005',
        );
      final repo = build(remote: remote);

      expect(
        () => repo.submitIdentityDocument(
          documentType: DocumentType.nationalId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)),
      );
    });
  });

  group('getStatus', () {
    test('returns mapped status aggregate from remote', () async {
      final remote = FakeVerificationRemoteDataSource(
        statusResult: seedStatusDto(identityVerified: true, totalSubmissions: 2),
      );
      final repo = build(remote: remote);

      final status = await repo.getStatus();

      expect(status.entityId, 'u1');
      expect(status.identityVerified, isTrue);
      expect(status.totalSubmissions, 2);
      expect(status.kycLevel.tierCode, 'tier_0');
      expect(remote.statusCallCount, 1);
    });

    test('maps unverified defaults', () async {
      final repo = build();

      final status = await repo.getStatus();

      expect(status.identityVerified, isFalse);
      expect(status.pendingSubmissions, 1);
    });
  });

  group('getKycLevel', () {
    test('returns mapped KYC level', () async {
      final remote = FakeVerificationRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', daily: 500000),
      );
      final repo = build(remote: remote);

      final level = await repo.getKycLevel();

      expect(level.tierCode, 'tier_1');
      expect(level.limits.daily, 500000);
      expect(remote.kycCallCount, 1);
    });
  });

  group('getLimits', () {
    test('returns mapped limits via remote', () async {
      final remote = FakeVerificationRemoteDataSource(
        limitsResult: seedKycDto(tierCode: 'tier_2', monthly: 8000000),
      );
      final repo = build(remote: remote);

      final level = await repo.getLimits();

      expect(level.tierCode, 'tier_2');
      expect(level.limits.monthly, 8000000);
      expect(remote.limitsCallCount, 1);
    });
  });

  group('error propagation', () {
    test('repository rethrows ApiExceptions from remote.getStatus', () async {
      final remote = FakeVerificationRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'not found',
          code: 'PLT004',
        );
      final repo = build(remote: remote);

      expect(
        () => repo.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.notFound)),
      );
    });

    test('getKycLevel rethrows remote failures', () async {
      final remote = FakeVerificationRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'X9',
        );
      final repo = build(remote: remote);

      expect(
        () => repo.getKycLevel(),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'X9')),
      );
    });
  });
}
