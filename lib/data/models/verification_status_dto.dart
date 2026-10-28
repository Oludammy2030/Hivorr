import 'package:hivorr/data/models/kyc_level_dto.dart';

/// One latest submission row projected by `verification_status_get`.
class VerificationSubmissionSummaryDto {
  const VerificationSubmissionSummaryDto({
    required this.submissionType,
    required this.status,
    required this.submittedAt,
    this.professionId,
    this.businessId,
    this.businessTradingName,
    this.reviewedAt,
    this.decisionNotes,
    this.credentialTitle,
  });

  factory VerificationSubmissionSummaryDto.fromJson(Map<String, dynamic> json) {
    return VerificationSubmissionSummaryDto(
      submissionType: (json['submission_type'] as String?) ?? '',
      professionId: json['profession_id'] as String?,
      businessId: json['business_id'] as String?,
      businessTradingName: json['business_trading_name'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      submittedAt:
          DateTime.tryParse((json['submitted_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse((json['reviewed_at'] as String?) ?? ''),
      decisionNotes: json['decision_notes'] as String?,
      credentialTitle: json['credential_title'] as String?,
    );
  }

  final String submissionType;
  final String? professionId;
  final String? businessId;
  final String? businessTradingName;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? decisionNotes;
  final String? credentialTitle;
}

/// Business membership/verification entry from `verification_status_get`.
class BusinessVerificationEntryDto {
  const BusinessVerificationEntryDto({
    required this.businessId,
    required this.tradingName,
    required this.registeredLegalName,
    this.cacNumber,
    required this.verificationStatus,
    required this.role,
    required this.isAuthorized,
    this.latestSubmission,
  });

  factory BusinessVerificationEntryDto.fromJson(Map<String, dynamic> json) {
    VerificationSubmissionSummaryDto? latest;
    final dynamic latestRaw = json['latest_submission'];
    if (latestRaw is Map<String, dynamic>) {
      latest = VerificationSubmissionSummaryDto.fromJson(<String, dynamic>{
        'submission_type': 'business_verification',
        'status': latestRaw['status'],
        'submitted_at': latestRaw['submitted_at'],
        'reviewed_at': latestRaw['reviewed_at'],
        'decision_notes': latestRaw['decision_notes'],
        'business_id': json['business_id'],
        'business_trading_name': json['trading_name'],
      });
    }
    return BusinessVerificationEntryDto(
      businessId: (json['business_id'] as String?) ?? '',
      tradingName: (json['trading_name'] as String?) ?? '',
      registeredLegalName: (json['registered_legal_name'] as String?) ?? '',
      cacNumber: json['cac_number'] as String?,
      verificationStatus: (json['verification_status'] as String?) ?? 'pending',
      role: (json['role'] as String?) ?? 'member',
      isAuthorized: (json['is_authorized'] as bool?) ?? false,
      latestSubmission: latest,
    );
  }

  final String businessId;
  final String tradingName;
  final String registeredLegalName;
  final String? cacNumber;
  final String verificationStatus;
  final String role;
  final bool isAuthorized;
  final VerificationSubmissionSummaryDto? latestSubmission;
}

/// Data Transfer Object mirroring the full `verification_status_get` aggregate
/// (EP-02-10).
///
/// Server shape (`supabase/migrations/20261027090001_account_verification_projection.sql`):
/// `{entity_id, kyc:{tier_code,status,limits{...}}, identity_verified:bool,
///   trade_verifications:[{profession_id, trade_verification_status,
///   professional_display_name}], latest_submissions:[{submission_type,
///   profession_id, business_id, business_trading_name, status, submitted_at,
///   reviewed_at, decision_notes, credential_title}], businesses:[{business_id,
///   trading_name, registered_legal_name, cac_number, verification_status,
///   role, is_authorized, latest_submission}], eligibility:{...},
///   pending_submissions:int, total_submissions:int}`.
class VerificationStatusDto {
  const VerificationStatusDto({
    required this.entityId,
    required this.kyc,
    required this.identityVerified,
    this.tradeVerifications = const <TradeVerificationDto>[],
    this.latestSubmissions = const <VerificationSubmissionSummaryDto>[],
    this.businesses = const <BusinessVerificationEntryDto>[],
    this.eligibility = const <String, dynamic>{},
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

    final Object? businessesRaw = json['businesses'];
    final List<BusinessVerificationEntryDto> businesses = businessesRaw is List
        ? businessesRaw
              .whereType<Map<String, dynamic>>()
              .map(BusinessVerificationEntryDto.fromJson)
              .toList(growable: false)
        : const <BusinessVerificationEntryDto>[];

    return VerificationStatusDto(
      entityId: (json['entity_id'] as String?) ?? '',
      kyc: kyc,
      identityVerified: (json['identity_verified'] as bool?) ?? false,
      tradeVerifications: trades,
      latestSubmissions: submissions,
      businesses: businesses,
      eligibility: json['eligibility'] is Map<String, dynamic>
          ? (json['eligibility'] as Map<String, dynamic>)
          : const <String, dynamic>{},
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
  final List<BusinessVerificationEntryDto> businesses;
  final Map<String, dynamic> eligibility;

  /// Whether the server projected the per-lane review state.
  ///
  /// Old backends omit `latest_submissions`; consumers then fall back to the
  /// aggregate counts instead of assuming "no submission".
  final bool hasLatestSubmissionData;

  final int pendingSubmissions;
  final int totalSubmissions;
}
