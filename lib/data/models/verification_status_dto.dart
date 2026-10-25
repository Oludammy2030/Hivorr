import 'package:hivorr/data/models/kyc_level_dto.dart';

/// One latest submission row projected by `verification_status_get`.
class VerificationSubmissionSummaryDto {
  const VerificationSubmissionSummaryDto({
    required this.submissionType,
    required this.status,
    required this.submittedAt,
    this.professionId,
    this.reviewedAt,
  });

  factory VerificationSubmissionSummaryDto.fromJson(Map<String, dynamic> json) {
    return VerificationSubmissionSummaryDto(
      submissionType: (json['submission_type'] as String?) ?? '',
      professionId: json['profession_id'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      submittedAt:
          DateTime.tryParse((json['submitted_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse((json['reviewed_at'] as String?) ?? ''),
    );
  }

  final String submissionType;
  final String? professionId;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
}

/// Data Transfer Object mirroring the full `verification_status_get` aggregate
/// (EP-02-10).
///
/// Server shape (`supabase/migrations/20261025090001_verification_submission_status.sql`):
/// `{entity_id, kyc:{tier_code,status,limits{...}}, identity_verified:bool,
///   trade_verifications:[{profession_id, trade_verification_status}],
///   latest_submissions:[{submission_type, profession_id, status,
///   submitted_at, reviewed_at}], pending_submissions:int,
///   total_submissions:int}`.
class VerificationStatusDto {
  const VerificationStatusDto({
    required this.entityId,
    required this.kyc,
    required this.identityVerified,
    this.tradeVerifications = const <TradeVerificationDto>[],
    this.latestSubmissions = const <VerificationSubmissionSummaryDto>[],
    this.hasLatestSubmissionData = false,
    required this.pendingSubmissions,
    required this.totalSubmissions,
  });

  factory VerificationStatusDto.fromJson(Map<String, dynamic> json) {
    final Object? kycRaw = json['kyc'];
    final KycLevelDto kyc = kycRaw is Map<String, dynamic>
        ? KycLevelDto.fromJson(kycRaw)
        : const KycLevelDto(
            tierCode: 'tier_0',
            status: 'pending',
            limits: KycLimitsDto(daily: 0, weekly: 0, monthly: 0, cashout: 0),
          );

    final Object? tradesRaw = json['trade_verifications'];
    final List<TradeVerificationDto> trades = tradesRaw is List
        ? tradesRaw
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> e) => TradeVerificationDto.fromJson(e))
              .toList(growable: false)
        : const <TradeVerificationDto>[];

    final Object? submissionsRaw = json['latest_submissions'];
    final List<VerificationSubmissionSummaryDto> submissions =
        submissionsRaw is List
        ? submissionsRaw
              .whereType<Map<String, dynamic>>()
              .map(VerificationSubmissionSummaryDto.fromJson)
              .toList(growable: false)
        : const <VerificationSubmissionSummaryDto>[];

    return VerificationStatusDto(
      entityId: (json['entity_id'] as String?) ?? '',
      kyc: kyc,
      identityVerified: (json['identity_verified'] as bool?) ?? false,
      tradeVerifications: trades,
      latestSubmissions: submissions,
      hasLatestSubmissionData: submissionsRaw is List,
      pendingSubmissions: (json['pending_submissions'] as num?)?.toInt() ?? 0,
      totalSubmissions: (json['total_submissions'] as num?)?.toInt() ?? 0,
    );
  }

  final String entityId;
  final KycLevelDto kyc;
  final bool identityVerified;
  final List<TradeVerificationDto> tradeVerifications;
  final List<VerificationSubmissionSummaryDto> latestSubmissions;

  /// Whether the server projected the per-lane review state.
  ///
  /// Old backends omit `latest_submissions`; consumers then fall back to the
  /// aggregate counts instead of assuming "no submission".
  final bool hasLatestSubmissionData;

  final int pendingSubmissions;
  final int totalSubmissions;
}
