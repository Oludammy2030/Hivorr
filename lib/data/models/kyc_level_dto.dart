/// Data Transfer Objects for the KYC read models (EP-02-10).
///
/// Mirror the `verification_kyc_level_get` / `verification_limits_get` / KYC
/// portion of `verification_status_get` envelopes
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:687-796`).
/// camelCase Dart fields map the snake_case server keys exactly via [fromJson].
abstract final class KycDto {
  const KycDto._();
}

/// Numeric transaction limits bound to a KYC tier (`numeric` columns).
class KycLimitsDto {
  const KycLimitsDto({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.cashout,
  });

  factory KycLimitsDto.fromJson(Map<String, dynamic> json) => KycLimitsDto(
        daily: _num(json['daily']) ?? 0,
        weekly: _num(json['weekly']) ?? 0,
        monthly: _num(json['monthly']) ?? 0,
        cashout: _num(json['cashout']) ?? 0,
      );

  final num daily;
  final num weekly;
  final num monthly;
  final num cashout;

  static num? _num(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

/// The assigned KYC tier read model.
class KycLevelDto {
  const KycLevelDto({
    required this.tierCode,
    required this.status,
    required this.limits,
  });

  factory KycLevelDto.fromJson(Map<String, dynamic> json) => KycLevelDto(
        tierCode: (json['tier_code'] as String?) ?? 'tier_0',
        status: (json['status'] as String?) ?? 'pending',
        limits: json['limits'] is Map<String, dynamic>
            ? KycLimitsDto.fromJson(json['limits'] as Map<String, dynamic>)
            : const KycLimitsDto(
                daily: 0,
                weekly: 0,
                monthly: 0,
                cashout: 0,
              ),
      );

  final String tierCode;
  final String status;
  final KycLimitsDto limits;
}

/// A single trade-verification entry (display-only for this task).
class TradeVerificationDto {
  const TradeVerificationDto({
    required this.professionId,
    required this.status,
  });

  factory TradeVerificationDto.fromJson(Map<String, dynamic> json) =>
      TradeVerificationDto(
        professionId: (json['profession_id'] as String?) ?? '',
        status:
            (json['trade_verification_status'] as String?) ?? 'unverified',
      );

  final String professionId;
  final String status;
}
