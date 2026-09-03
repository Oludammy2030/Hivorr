import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Pure-function limit helpers for KYC tier enforcement (EP-02-12 §5.4).
///
/// No I/O, no globals, no Flutter imports — trivially testable. Used by
/// downstream `EP-02-16` payout screens to gate `financial_withdraw` before
/// network, reducing server-side `PLT006` rejections on slow networks.
abstract final class KycLimitGuard {
  /// Whether a transaction of [amount] is within the daily limit.
  static bool canTransact({required KycLimits limits, required num amount}) =>
      amount > 0 && amount <= limits.daily;

  /// Whether a cashout of [amount] is within the cashout limit.
  static bool isCashoutAllowed({required KycLimits limits, required num amount}) =>
      amount > 0 && amount <= limits.cashout;

  /// Returns the remaining limit for the given [window] after [spent].
  ///
  /// [window] must be `'daily'`, `'weekly'`, or `'monthly'`.
  static num remainingFor(String window, KycLimits limits, num spent) {
    final num limit;
    switch (window) {
      case 'daily':
        limit = limits.daily;
      case 'weekly':
        limit = limits.weekly;
      case 'monthly':
        limit = limits.monthly;
      default:
        throw ArgumentError('Invalid window: $window');
    }
    return limit - spent;
  }

  /// Suggests the lowest tier that can accommodate [requestedAmount] cashout.
  ///
  /// Returns `null` if the current tier already supports the amount.
  static KycTier? suggestedUpgrade(KycLevel current, num requestedAmount) {
    if (requestedAmount <= current.limits.cashout) return null;
    for (final KycTier tier in KycTier.values) {
      if (tier.isAtLeast(KycTier.tier1)) {
        // Approximate limits for suggestion — real limits come from server.
        final num cashout = _cashoutLimitForTier(tier);
        if (cashout >= requestedAmount) return tier;
      }
    }
    return null;
  }

  static num _cashoutLimitForTier(KycTier tier) {
    switch (tier) {
      case KycTier.tier0:
        return 0;
      case KycTier.tier1:
        return 50000;
      case KycTier.tier2:
        return 200000;
      case KycTier.tier3:
        return 1000000;
    }
  }
}
