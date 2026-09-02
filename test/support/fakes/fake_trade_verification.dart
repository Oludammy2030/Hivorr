// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/trade_verification_remote_data_source.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

import 'fake_verification.dart' show seedKycDto;

/// In-memory [TradeVerificationRemoteDataSource] for provider/repository tests.
///
/// Surfaces scripted DTOs with call counters; set [nextError] to exercise
/// failure paths exactly as the real RPC layer throws [ApiException]. Use
/// [statusResultOverride] to drive successive `getStatus()` responses (e.g. to
/// simulate an admin approval between polls).
class FakeTradeVerificationRemoteDataSource
    implements TradeVerificationRemoteDataSource {
  FakeTradeVerificationRemoteDataSource({
    VerificationSubmissionDto? submitResult,
    VerificationStatusDto? statusResult,
  })  : _submitResult = submitResult ?? tradeSubmissionDto(),
        _statusResult = statusResult ?? tradeStatusDto();

  final VerificationSubmissionDto _submitResult;
  VerificationStatusDto _statusResult;

  /// Overrides the status served by the next `getStatus()` call.
  void setStatusResult(VerificationStatusDto dto) => _statusResult = dto;

  /// Appends a per-profession entry to the served aggregate.
  void addTradeStatus({
    required String professionId,
    required String status,
  }) {
    final updated = VerificationStatusDto(
      entityId: _statusResult.entityId,
      kyc: _statusResult.kyc,
      identityVerified: _statusResult.identityVerified,
      tradeVerifications: <TradeVerificationDto>[
        ..._statusResult.tradeVerifications,
        TradeVerificationDto(professionId: professionId, status: status),
      ],
      pendingSubmissions: _statusResult.pendingSubmissions,
      totalSubmissions: _statusResult.totalSubmissions,
    );
    _statusResult = updated;
  }

  ApiException? nextError;
  int submitCallCount = 0;
  int statusCallCount = 0;
  String? lastCredentialId;
  String? lastSubmissionType;
  String? lastEntityId;

  @override
  Future<VerificationSubmissionDto> submit({
    required String credentialId,
    String submissionType = 'trade_proof',
  }) async {
    submitCallCount++;
    lastCredentialId = credentialId;
    lastSubmissionType = submissionType;
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return _submitResult;
  }

  @override
  Future<VerificationStatusDto> getStatus({String? entityId}) async {
    statusCallCount++;
    lastEntityId = entityId;
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return _statusResult;
  }
}

/// In-memory [TradeVerificationRepository] for provider/widget tests.
class FakeTradeVerificationRepository implements TradeVerificationRepository {
  FakeTradeVerificationRepository({
    TradeVerificationStatus? status,
    String defaultStatus = 'pending',
  })  : _status = status ??
            TradeVerificationStatus(
              tradeVerifications: <TradeVerification>[
                TradeVerification(professionId: 'p1', status: defaultStatus),
              ],
            );

  TradeVerificationStatus _status;
  ApiException? nextError;
  int submitCallCount = 0;
  int statusCallCount = 0;
  TradeProofType? lastType;
  String? lastProfessionId;

  /// Mutates the status snapshot the fake serves (e.g. after admin approval).
  void setStatus(TradeVerificationStatus status) => _status = status;

  @override
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    submitCallCount++;
    lastType = type;
    lastProfessionId = professionId;
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return VerificationSubmission(
      id: 'trade-sub-1',
      entityId: 'u1',
      credentialId: 'cred-1',
      documentType: DocumentType.nationalId,
      status: VerificationStatusKind.pending,
      submittedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
  }

  @override
  Future<TradeVerificationStatus> getStatus() async {
    statusCallCount++;
    if (nextError != null) {
      final ApiException e = nextError!;
      nextError = null;
      throw e;
    }
    return _status;
  }
}

// ---------------------------------------------------------------------------
// Fixture builders shared across the trade tests.
// ---------------------------------------------------------------------------

/// A default pending trade submission DTO.
VerificationSubmissionDto tradeSubmissionDto({
  String id = 'trade-sub-1',
  String entityId = 'u1',
  String credentialId = 'cred-1',
  String status = 'pending',
  DateTime? submittedAt,
}) =>
    VerificationSubmissionDto(
      id: id,
      entityId: entityId,
      credentialId: credentialId,
      submissionType: 'trade_proof',
      status: status,
      submittedAt: submittedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
    );

/// A status aggregate DTO with the given per-profession [statuses].
VerificationStatusDto tradeStatusDto({
  String entityId = 'u1',
  bool identityVerified = false,
  Map<String, String> statuses = const <String, String>{'p1': 'unverified'},
  int pendingSubmissions = 0,
  int totalSubmissions = 0,
}) =>
    VerificationStatusDto(
      entityId: entityId,
      kyc: seedKycDto(),
      identityVerified: identityVerified,
      tradeVerifications: statuses.entries
          .map((MapEntry<String, String> e) =>
              TradeVerificationDto(professionId: e.key, status: e.value))
          .toList(growable: false),
      pendingSubmissions: pendingSubmissions,
      totalSubmissions: totalSubmissions,
    );

/// A trade aggregate entity with the given per-profession [statuses].
TradeVerificationStatus tradeStatusEntity({
  bool identityVerified = false,
  Map<String, String> statuses = const <String, String>{'p1': 'unverified'},
}) =>
    TradeVerificationStatus(
      identityVerified: identityVerified,
      tradeVerifications: statuses.entries
          .map((MapEntry<String, String> e) =>
              TradeVerification(professionId: e.key, status: e.value))
          .toList(growable: false),
    );
