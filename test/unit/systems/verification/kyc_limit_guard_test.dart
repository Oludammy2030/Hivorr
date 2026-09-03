import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:hivorr/systems/verification/services/kyc_limit_guard.dart';

void main() {
  const KycLimits tier1 = KycLimits(
    daily: 50000,
    weekly: 200000,
    monthly: 800000,
    cashout: 100000,
  );

  group('KycLimitGuard.canTransact', () {
    test('true when amount within daily limit', () {
      expect(
        KycLimitGuard.canTransact(limits: tier1, amount: 50000),
        isTrue,
      );
    });

    test('false when amount exceeds daily limit', () {
      expect(
        KycLimitGuard.canTransact(limits: tier1, amount: 50001),
        isFalse,
      );
    });

    test('false for zero or negative amounts', () {
      expect(KycLimitGuard.canTransact(limits: tier1, amount: 0), isFalse);
      expect(KycLimitGuard.canTransact(limits: tier1, amount: -10), isFalse);
    });
  });

  group('KycLimitGuard.isCashoutAllowed', () {
    test('true when amount within cashout limit', () {
      expect(
        KycLimitGuard.isCashoutAllowed(limits: tier1, amount: 100000),
        isTrue,
      );
    });

    test('false when amount exceeds cashout limit', () {
      expect(
        KycLimitGuard.isCashoutAllowed(limits: tier1, amount: 100001),
        isFalse,
      );
    });

    test('false for zero', () {
      expect(KycLimitGuard.isCashoutAllowed(limits: tier1, amount: 0), isFalse);
    });
  });

  group('KycLimitGuard.remainingFor', () {
    test('subtracts spent from the correct window', () {
      expect(KycLimitGuard.remainingFor('daily', tier1, 30000), 20000);
      expect(KycLimitGuard.remainingFor('weekly', tier1, 50000), 150000);
      expect(KycLimitGuard.remainingFor('monthly', tier1, 100000), 700000);
    });

    test('throws for an invalid window', () {
      expect(
        () => KycLimitGuard.remainingFor('yearly', tier1, 0),
        throwsArgumentError,
      );
    });
  });

  group('KycLimitGuard.suggestedUpgrade', () {
    test('null when the current tier supports the amount', () {
      const KycLevel current = KycLevel(
        tierCode: 'tier_1',
        status: 'active',
        limits: tier1,
      );
      expect(
        KycLimitGuard.suggestedUpgrade(current, 50000),
        isNull,
      );
    });

    test('suggests a higher tier when the amount exceeds cashout', () {
      const KycLevel current = KycLevel(
        tierCode: 'tier_1',
        status: 'active',
        limits: tier1,
      );
      final KycTier? suggestion =
          KycLimitGuard.suggestedUpgrade(current, 600000);
      expect(suggestion, isNotNull);
      expect(suggestion!.index, greaterThan(KycTier.tier1.index));
    });

    test('is pure — no I/O, no mutation of inputs', () {
      const KycLevel current = KycLevel(
        tierCode: 'tier_1',
        status: 'active',
        limits: tier1,
      );
      final before = tier1.cashout;
      KycLimitGuard.suggestedUpgrade(current, 600000);
      expect(tier1.cashout, before);
    });
  });
}
