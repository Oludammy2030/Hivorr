// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/datasources/remote/verification_remote_data_source.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileObject;

/// In-memory [VerificationRemoteDataSource] for provider/repository tests.
///
/// Surfaces scripted DTOs with call counters; set [nextError] to exercise
/// failure paths exactly as the real RPC layer throws [ApiException].
class FakeVerificationRemoteDataSource implements VerificationRemoteDataSource {
  FakeVerificationRemoteDataSource({
    VerificationSubmissionDto? submitResult,
    VerificationStatusDto? statusResult,
    KycLevelDto? kycResult,
    KycLevelDto? limitsResult,
  })  : _submitResult = submitResult ?? seedSubmissionDto(),
        _statusResult = statusResult ?? seedStatusDto(),
        _kycResult = kycResult ?? seedKycDto(),
        _limitsResult = limitsResult ?? seedKycDto(tierCode: 'tier_1');

  final VerificationSubmissionDto _submitResult;
  final VerificationStatusDto _statusResult;
  final KycLevelDto _kycResult;
  final KycLevelDto _limitsResult;

  ApiException? nextError;
  int submitCallCount = 0;
  int statusCallCount = 0;
  int kycCallCount = 0;
  int limitsCallCount = 0;
  String? lastCredentialId;
  String? lastSubmissionType;
  String? lastEntityId;

  @override
  Future<VerificationSubmissionDto> submit({
    required String credentialId,
    String? submissionType,
  }) async {
    submitCallCount++;
    lastCredentialId = credentialId;
    lastSubmissionType = submissionType;
    if (nextError != null) throw nextError!;
    return _submitResult;
  }

  @override
  Future<VerificationStatusDto> getStatus({String? entityId}) async {
    statusCallCount++;
    lastEntityId = entityId;
    if (nextError != null) throw nextError!;
    return _statusResult;
  }

  @override
  Future<KycLevelDto> getKycLevel() async {
    kycCallCount++;
    if (nextError != null) throw nextError!;
    return _kycResult;
  }

  @override
  Future<KycLevelDto> getLimits() async {
    limitsCallCount++;
    if (nextError != null) throw nextError!;
    return _limitsResult;
  }
}

/// Scriptable [StorageService] for repository tests.
///
/// Records the last upload path + bucket and returns a canned storage key.
/// Set [nextError] to simulate a failing upload.
class FakeStorageService implements StorageService {
  ApiException? nextError;
  int uploadCallCount = 0;
  String? lastBucket;
  String? lastPath;
  String? lastMimeType;
  int? lastByteLength;
  void Function(int sent, int total)? lastOnProgress;
  String returnedKey = 'credential-documents/uploaded/object.bin';

  @override
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
    void Function(int sent, int total)? onProgress,
    bool upsert = false,
  }) async {
    uploadCallCount++;
    lastBucket = bucket;
    lastPath = path;
    lastMimeType = mimeType;
    lastByteLength = bytes.length;
    lastOnProgress = onProgress;
    if (nextError != null) throw nextError!;
    return returnedKey;
  }

  @override
  void validateForBucket({
    required String bucket,
    required String mimeType,
    required int byteLength,
  }) {
    if (nextError != null) throw nextError!;
  }

  @override
  Future<Uint8List> download({required String bucket, required String path}) =>
      Future<Uint8List>.value(Uint8List(0));

  @override
  Future<void> remove({required String bucket, required List<String> paths}) =>
      Future<void>.value();

  @override
  String getPublicUrl({required String bucket, required String path}) =>
      'https://example/$bucket/$path';

  @override
  Future<String> createSignedUrl({
    required String bucket,
    required String path,
    required int expiresInSeconds,
  }) async =>
      'https://example/sign/$path';

  @override
  Future<List<FileObject>> list({
    required String bucket,
    required String path,
    int limit = 100,
  }) async =>
      <FileObject>[];
}

/// In-memory [VerificationRepository] for provider/widget tests.
class FakeVerificationRepository implements VerificationRepository {
  FakeVerificationRepository({
    VerificationStatusKind defaultStatus = VerificationStatusKind.pending,
    bool identityVerified = false,
  })  : _defaultStatus = defaultStatus,
        _identityVerified = identityVerified {
    _status = seedStatusEntity(
      identityVerified: identityVerified,
      totalSubmissions: identityVerified ? 1 : 0,
    );
  }

  final VerificationStatusKind _defaultStatus;
  final bool _identityVerified;

  VerificationStatus? _status;
  KycLevel? _kyc;
  ApiException? nextError;
  int submitCallCount = 0;
  int statusCallCount = 0;
  bool shouldStopPolling = false;

  /// Mutates the status snapshot the fake serves (e.g. after admin approval).
  void setStatus(VerificationStatus status) => _status = status;

  void setKyc(KycLevel kyc) => _kyc = kyc;

  @override
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    submitCallCount++;
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return VerificationSubmission(
      id: 'sub-1',
      entityId: 'u1',
      credentialId: 'cred-1',
      documentType: documentType,
      status: _defaultStatus,
      submittedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
  }

  @override
  Future<VerificationStatus> getStatus() async {
    statusCallCount++;
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return _status!;
  }

  @override
  Future<KycLevel> getKycLevel() async {
    if (_kyc != null) return _kyc!;
    if (_identityVerified || _status!.identityVerified) {
      return const KycLevel(
        tierCode: 'tier_1',
        status: 'active',
        limits: KycLimits(daily: 500000, weekly: 2000000, monthly: 8000000, cashout: 1000000),
      );
    }
    return const KycLevel(
      tierCode: 'tier_0',
      status: 'pending',
      limits: KycLimits(daily: 0, weekly: 0, monthly: 0, cashout: 0),
    );
  }

  @override
  Future<KycLevel> getLimits() async => getKycLevel();
}

// ---------------------------------------------------------------------------
// Fixture builders (DTOs + entities) shared across the verification tests.
// ---------------------------------------------------------------------------

/// A default pending submission DTO.
VerificationSubmissionDto seedSubmissionDto({
  String id = 'sub-1',
  String entityId = 'u1',
  String credentialId = 'cred-1',
  String status = 'pending',
  DateTime? submittedAt,
}) =>
    VerificationSubmissionDto(
      id: id,
      entityId: entityId,
      credentialId: credentialId,
      submissionType: 'identity_document',
      status: status,
      submittedAt: submittedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
    );

/// A default (unverified) status aggregate DTO.
VerificationStatusDto seedStatusDto({
  String entityId = 'u1',
  String tierCode = 'tier_0',
  String kycStatus = 'pending',
  bool identityVerified = false,
  int pendingSubmissions = 1,
  int totalSubmissions = 1,
}) =>
    VerificationStatusDto(
      entityId: entityId,
      kyc: seedKycDto(tierCode: tierCode, status: kycStatus),
      identityVerified: identityVerified,
      tradeVerifications: const <TradeVerificationDto>[],
      pendingSubmissions: pendingSubmissions,
      totalSubmissions: totalSubmissions,
    );

/// A default KYC level DTO.
KycLevelDto seedKycDto({
  String tierCode = 'tier_0',
  String status = 'pending',
  num daily = 0,
  num weekly = 0,
  num monthly = 0,
  num cashout = 0,
}) =>
    KycLevelDto(
      tierCode: tierCode,
      status: status,
      limits: KycLimitsDto(
        daily: daily,
        weekly: weekly,
        monthly: monthly,
        cashout: cashout,
      ),
    );

/// A default status entity.
VerificationStatus seedStatusEntity({
  String entityId = 'u1',
  String tierCode = 'tier_0',
  bool identityVerified = false,
  int pendingSubmissions = 1,
  int totalSubmissions = 1,
}) =>
    VerificationStatus(
      entityId: entityId,
      kycLevel: KycLevel(
        tierCode: tierCode,
        status: 'pending',
        limits: const KycLimits(
          daily: 0, weekly: 0, monthly: 0, cashout: 0),
      ),
      identityVerified: identityVerified,
      tradeVerifications: const <TradeVerification>[],
      pendingSubmissions: pendingSubmissions,
      totalSubmissions: totalSubmissions,
    );
