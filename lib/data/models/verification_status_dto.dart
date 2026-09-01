import 'package:hivorr/data/models/kyc_level_dto.dart';

/// Data Transfer Object mirroring the full `verification_status_get` aggregate
/// (EP-02-10).
///
/// Server shape (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681`):
/// `{entity_id, kyc:{tier_code,status,limits{...}}, identity_verified:bool,
///   trade_verifications:[{profession_id, trade_verification_status}],
///   pending_submissions:int, total_submissions:int}`.
class VerificationStatusDto {
  const VerificationStatusDto({
    required this.entityId,
    required this.kyc,
    required this.identityVerified,
    this.tradeVerifications = const <TradeVerificationDto>[],
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
            .map((Map<String, dynamic> e) =>
                TradeVerificationDto.fromJson(e))
            .toList(growable: false)
        : const <TradeVerificationDto>[];

    return VerificationStatusDto(
      entityId: (json['entity_id'] as String?) ?? '',
      kyc: kyc,
      identityVerified: (json['identity_verified'] as bool?) ?? false,
      tradeVerifications: trades,
      pendingSubmissions: (json['pending_submissions'] as num?)?.toInt() ?? 0,
      totalSubmissions: (json['total_submissions'] as num?)?.toInt() ?? 0,
    );
  }

  final String entityId;
  final KycLevelDto kyc;
  final bool identityVerified;
  final List<TradeVerificationDto> tradeVerifications;
  final int pendingSubmissions;
  final int totalSubmissions;
}
