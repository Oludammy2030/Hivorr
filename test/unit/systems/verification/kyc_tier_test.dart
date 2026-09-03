import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

void main() {
  group('KycTier.fromCode', () {
    test('maps the four server tier codes', () {
      expect(KycTier.fromCode('tier_0'), KycTier.tier0);
      expect(KycTier.fromCode('tier_1'), KycTier.tier1);
      expect(KycTier.fromCode('tier_2'), KycTier.tier2);
      expect(KycTier.fromCode('tier_3'), KycTier.tier3);
    });

    test('falls back to tier0 for unknown codes', () {
      expect(KycTier.fromCode('garbage'), KycTier.tier0);
      expect(KycTier.fromCode(''), KycTier.tier0);
    });
  });

  group('KycTier verification flags', () {
    test('tier0 is unverified', () {
      expect(KycTier.tier0.isVerified, isFalse);
      expect(KycTier.tier0.isAtLeastVerified, isFalse);
    });

    test('tier1..tier3 are verified', () {
      expect(KycTier.tier1.isVerified, isTrue);
      expect(KycTier.tier2.isVerified, isTrue);
      expect(KycTier.tier3.isVerified, isTrue);
      expect(KycTier.tier1.isAtLeastVerified, isTrue);
      expect(KycTier.tier3.isAtLeastVerified, isTrue);
    });
  });

  group('KycTier.isAtLeast', () {
    test('lexicographic ordering holds for tier_0..tier_3', () {
      expect(KycTier.tier3.isAtLeast(KycTier.tier1), isTrue);
      expect(KycTier.tier1.isAtLeast(KycTier.tier3), isFalse);
      expect(KycTier.tier2.isAtLeast(KycTier.tier2), isTrue);
      expect(KycTier.tier0.isAtLeast(KycTier.tier0), isTrue);
    });
  });

  group('KycTier labels', () {
    test('exposes friendly display labels', () {
      expect(KycTier.tier0.displayLabel, 'Unverified');
      expect(KycTier.tier3.displayLabel, 'Premium');
    });

    test('cashoutLimit reads from the given KycLimits', () {
      const KycLimits limits = KycLimits(
        daily: 1, weekly: 2, monthly: 3, cashout: 100000,
      );
      expect(KycTier.tier1.cashoutLimit(limits), 100000);
    });
  });
}
