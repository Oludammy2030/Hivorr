import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/mappers/verification_mapper.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

void main() {
  KycLevelDto level({
    String tier = 'tier_1',
    String status = 'active',
    num daily = 500000,
    num weekly = 2000000,
    num monthly = 8000000,
    num cashout = 1000000,
  }) =>
      KycLevelDto(
        tierCode: tier,
        status: status,
        limits: KycLimitsDto(
          daily: daily,
          weekly: weekly,
          monthly: monthly,
          cashout: cashout,
        ),
      );

  group('VerificationMapper.kycToEntity', () {
    test('maps a complete level preserving tier, status and limits', () {
      final KycLevel entity = VerificationMapper.kycToEntity(level());

      expect(entity.tierCode, 'tier_1');
      expect(entity.status, 'active');
      expect(entity.limits.daily, 500000);
      expect(entity.limits.weekly, 2000000);
      expect(entity.limits.monthly, 8000000);
      expect(entity.limits.cashout, 1000000);
      expect(entity.isVerified, isTrue);
    });

    test('tier0 all-zero level maps to an unverified level', () {
      final KycLevel entity = VerificationMapper.kycToEntity(
        level(tier: 'tier_0', cashout: 0),
      );

      expect(entity.tierCode, 'tier_0');
      expect(entity.isVerified, isFalse);
      expect(entity.limits.cashout, 0);
    });

    test('status pending maps to an unverified level', () {
      final KycLevel entity =
          VerificationMapper.kycToEntity(level(status: 'pending'));
      expect(entity.isVerified, isFalse);
    });
  });

  group('VerificationMapper.limitsToEntity', () {
    test('maps all four limit windows', () {
      final KycLimits limits = VerificationMapper.limitsToEntity(
        KycLimitsDto(daily: 1, weekly: 2, monthly: 3, cashout: 4),
      );

      expect(limits.daily, 1);
      expect(limits.weekly, 2);
      expect(limits.monthly, 3);
      expect(limits.cashout, 4);
    });
  });

  group('VerificationMapper.statusToEntity', () {
    test('maps the aggregate including trade verifications', () {
      final VerificationStatusDto dto = VerificationStatusDto(
        entityId: 'u1',
        kyc: level(),
        identityVerified: true,
        tradeVerifications: const <TradeVerificationDto>[
          TradeVerificationDto(
            professionId: 'p1',
            status: 'approved',
          ),
        ],
        pendingSubmissions: 1,
        totalSubmissions: 2,
      );

      final VerificationStatus status =
          VerificationMapper.statusToEntity(dto);

      expect(status.entityId, 'u1');
      expect(status.identityVerified, isTrue);
      expect(status.kycLevel.tierCode, 'tier_1');
      expect(status.tradeVerifications, hasLength(1));
      expect(status.tradeVerifications.single.professionId, 'p1');
      expect(status.pendingSubmissions, 1);
      expect(status.totalSubmissions, 2);
    });
  });

  group('VerificationMapper.kycTierFromCode', () {
    test('maps every server tier code', () {
      expect(VerificationMapper.kycTierFromCode('tier_0'), KycTier.tier0);
      expect(VerificationMapper.kycTierFromCode('tier_1'), KycTier.tier1);
      expect(VerificationMapper.kycTierFromCode('tier_2'), KycTier.tier2);
      expect(VerificationMapper.kycTierFromCode('tier_3'), KycTier.tier3);
    });

    test('falls back to tier0 for unknown codes', () {
      expect(VerificationMapper.kycTierFromCode('unknown'), KycTier.tier0);
      expect(VerificationMapper.kycTierFromCode(''), KycTier.tier0);
    });
  });

  group('VerificationMapper.kycTierLabel', () {
    test('returns the friendly label for known codes', () {
      expect(VerificationMapper.kycTierLabel('tier_0'), 'Unverified');
      expect(VerificationMapper.kycTierLabel('tier_3'), 'Premium');
    });

    test('falls back for unknown codes', () {
      expect(VerificationMapper.kycTierLabel('nope'), 'Unverified');
    });
  });
}
