import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/business_remote_data_source.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/models/business_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/data/repositories/business_repository_impl.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';
import '../../../support/fakes/fake_supabase.dart';
import '../../../support/fakes/fake_verification.dart';

/// In-memory [BusinessRemoteDataSource] for repository tests.
class FakeBusinessRemoteDataSource implements BusinessRemoteDataSource {
  int listCalls = 0;
  int createCalls = 0;
  int joinCalls = 0;
  int leaveCalls = 0;
  int credentialCalls = 0;
  int queueCalls = 0;
  String? lastBusinessId;
  String? lastTitle;

  @override
  Future<List<BusinessDto>> listMine({required String entityId}) async {
    listCalls++;
    return const <BusinessDto>[];
  }

  @override
  Future<BusinessDto> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  }) async {
    createCalls++;
    return BusinessDto(
      id: 'biz-1',
      tradingName: tradingName,
      registeredLegalName: registeredLegalName,
      cacNumber: cacNumber,
      status: 'pending',
    );
  }

  @override
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  }) async {
    joinCalls++;
    lastBusinessId = businessId;
  }

  @override
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  }) async {
    leaveCalls++;
    lastBusinessId = businessId;
  }

  @override
  Future<Map<String, dynamic>> submitCredential({
    required String businessId,
    required String title,
    required String documentPath,
  }) async {
    credentialCalls++;
    lastBusinessId = businessId;
    lastTitle = title;
    return <String, dynamic>{'id': 'cred-9'};
  }

  @override
  Future<VerificationSubmissionDto> queueSubmission({
    required String credentialId,
  }) async {
    queueCalls++;
    return VerificationSubmissionDto(
      id: 'sub-9',
      entityId: 'u1',
      credentialId: credentialId,
      submissionType: 'business_verification',
      status: 'pending',
      submittedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
  }
}

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
  const String mimeType = 'image/png';
  const String fileName = 'cac.png';

  BusinessRepositoryImpl build({
    FakeBusinessRemoteDataSource? remote,
    bool signedIn = true,
  }) => BusinessRepositoryImpl(
    remote: remote ?? FakeBusinessRemoteDataSource(),
    storage: FakeStorageService(),
    supabase: MockSupabaseClientFactory.create(
      currentUser: signedIn ? fakeUser('u1') : null,
    ),
  );

  group('BusinessRepositoryImpl fail-fast validation', () {
    test('empty trading name never reaches the remote (PLT003)', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(remote: remote);
      await expectLater(
        repo.createBusiness(
          tradingName: '  ',
          registeredLegalName: 'Amara Foods Ltd',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.createCalls, 0);
    });

    test('empty legal name never reaches the remote (PLT003)', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(remote: remote);
      await expectLater(
        repo.createBusiness(
          tradingName: 'Amara Foods',
          registeredLegalName: '',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('overlong CAC never reaches the remote (PLT003)', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(remote: remote);
      await expectLater(
        repo.createBusiness(
          tradingName: 'Amara Foods',
          registeredLegalName: 'Amara Foods Ltd',
          cacNumber: List<String>.filled(65, 'x').join(),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.createCalls, 0);
    });

    test('blank business id never reaches the remote (PLT003)', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(remote: remote);
      await expectLater(
        repo.joinBusiness(businessId: '  ', entityId: 'u1'),
        throwsA(isA<ApiException>()),
      );
      expect(remote.joinCalls, 0);
    });

    test('signed-out document submit fails closed (PLT001)', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(
        remote: remote,
        signedIn: false,
      );
      await expectLater(
        repo.submitDocument(
          businessId: 'biz-1',
          title: 'CAC certificate',
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.auth,
          ),
        ),
      );
      expect(remote.credentialCalls, 0);
    });
  });

  group('BusinessRepositoryImpl happy paths', () {
    test('create returns the pending business', () async {
      final BusinessRepositoryImpl repo = build();
      final Business created = await repo.createBusiness(
        tradingName: 'Amara Foods',
        registeredLegalName: 'Amara Foods Ltd',
        cacNumber: 'CAC-001',
      );
      expect(created.id, 'biz-1');
      expect(created.isPending, isTrue);
      expect(created.cacNumber, 'CAC-001');
    });

    test('submit uploads then queues with the credential id', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(remote: remote);
      final VerificationSubmission submission = await repo.submitDocument(
        businessId: 'biz-1',
        title: 'CAC certificate',
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      expect(submission.id, 'sub-9');
      expect(submission.credentialId, 'cred-9');
      expect(remote.credentialCalls, 1);
      expect(remote.queueCalls, 1);
      expect(remote.lastBusinessId, 'biz-1');
      expect(remote.lastTitle, 'CAC certificate');
    });

    test('leave delegates to the remote seam', () async {
      final FakeBusinessRemoteDataSource remote = FakeBusinessRemoteDataSource();
      final BusinessRepositoryImpl repo = build(remote: remote);
      await repo.leaveBusiness(businessId: 'biz-1', entityId: 'u1');
      expect(remote.leaveCalls, 1);
      expect(remote.lastBusinessId, 'biz-1');
    });
  });
}
