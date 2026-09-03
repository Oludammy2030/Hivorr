// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/kyc_remote_data_source.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';

/// In-memory [KycRemoteDataSource] for repository/provider tests.
///
/// Surfaces scripted DTOs with call counters; set [nextError] to exercise
/// failure paths exactly as the real RPC layer throws [ApiException].
class FakeKycRemoteDataSource implements KycRemoteDataSource {
  FakeKycRemoteDataSource({
    KycLevelDto? kycResult,
    KycLimitsDto? limitsResult,
    VerificationStatusDto? statusResult,
  })  : kycResult = kycResult ?? seedKycDto(),
        limitsResult = limitsResult ?? seedKycLimitsDto(),
        statusResult = statusResult ?? seedKycStatusDto();

  KycLevelDto kycResult;
  KycLimitsDto limitsResult;
  VerificationStatusDto statusResult;

  ApiException? nextError;
  int kycCallCount = 0;
  int limitsCallCount = 0;
  int statusCallCount = 0;

  /// When true, [getKycLevel] never completes (simulates an in-flight load).
  bool blockLevel = false;

  /// Optional script of level responses consumed in order; the last entry
  /// repeats. When null, every call returns [kycResult]. Lets a test simulate
  /// a server-authoritative upgrade between the initial fetch and a re-read.
  List<KycLevelDto>? kycScript;

  @override
  Future<KycLevelDto> getKycLevel() async {
    kycCallCount++;
    if (blockLevel) {
      return Completer<KycLevelDto>().future;
    }
    if (nextError != null) throw nextError!;
    final script = kycScript;
    if (script != null && script.isNotEmpty) {
      final int index = (kycCallCount - 1).clamp(0, script.length - 1);
      return script[index];
    }
    return kycResult;
  }

  @override
  Future<KycLimitsDto> getLimits() async {
    limitsCallCount++;
    if (nextError != null) throw nextError!;
    return limitsResult;
  }

  @override
  Future<VerificationStatusDto> getStatus({String? entityId}) async {
    statusCallCount++;
    if (nextError != null) throw nextError!;
    return statusResult;
  }
}

/// A default (tier_0, unverified) KYC level DTO.
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

/// A default KYC limits DTO (tier_1-style limits).
KycLimitsDto seedKycLimitsDto({
  num daily = 500000,
  num weekly = 2000000,
  num monthly = 8000000,
  num cashout = 1000000,
}) =>
    KycLimitsDto(
      daily: daily,
      weekly: weekly,
      monthly: monthly,
      cashout: cashout,
    );

/// A default status aggregate DTO.
VerificationStatusDto seedKycStatusDto({
  String entityId = 'u1',
  String tierCode = 'tier_0',
  bool identityVerified = false,
  int pending = 1,
  int total = 1,
}) =>
    VerificationStatusDto(
      entityId: entityId,
      kyc: seedKycDto(tierCode: tierCode, status: 'pending'),
      identityVerified: identityVerified,
      tradeVerifications: const <TradeVerificationDto>[],
      pendingSubmissions: pending,
      totalSubmissions: total,
    );
