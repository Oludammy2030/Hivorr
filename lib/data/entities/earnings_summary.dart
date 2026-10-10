/// Per-currency earnings aggregate for the visibility layer (EP-03-16).
///
/// Mirrors the `service_earnings_summary` RPC `data` object
/// (`supabase/migrations/20261008090001_service_earnings_visibility.sql`).
/// Pure Dart domain — every figure is server-computed over
/// `financial_transactions` + `financial_balances` + `financial_escrow`; the
/// client renders these values verbatim and never recomputes settlement
/// (AGENT.md Rule 4).
class EarningsMonthBucket {
  const EarningsMonthBucket({
    required this.month,
    required this.earned,
    required this.releaseCount,
  });

  /// First day of the bucket month (server `YYYY-MM-DD`, UTC).
  final DateTime month;

  /// Server-aggregated earned amount for the month (display-only).
  final double earned;

  /// Server-counted inbound releases for the month (display-only).
  final int releaseCount;
}

/// Server-verified earnings summary for one currency (EP-03-16).
class EarningsSummary {
  const EarningsSummary({
    required this.currencyCode,
    required this.availableBalance,
    required this.heldBalance,
    required this.pendingBalance,
    required this.lifetimeEarned,
    required this.releaseCount,
    required this.completedContracts,
    required this.totalWithdrawn,
    required this.frozenCount,
    required this.monthly,
  });

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String currencyCode;

  /// Available for immediate use (from `financial_balances`).
  final double availableBalance;

  /// Held by escrow or pending resolution (from `financial_balances`).
  final double heldBalance;

  /// Pending deposit confirmation (from `financial_balances`).
  final double pendingBalance;

  /// Server-aggregated lifetime earned (inbound `escrow_release` rows).
  final double lifetimeEarned;

  /// Server-counted inbound releases.
  final int releaseCount;

  /// Server-counted distinct released contracts.
  final int completedContracts;

  /// Server-aggregated lifetime withdrawn.
  final double totalWithdrawn;

  /// Server-counted disputed escrows touching the caller.
  final int frozenCount;

  /// Trailing 6 calendar-month buckets, oldest first (honest zeros kept).
  final List<EarningsMonthBucket> monthly;

  /// Whether any earned amount has been recorded.
  bool get hasEarnings => lifetimeEarned > 0;

  /// Whether any escrow is frozen in dispute.
  bool get hasFrozen => frozenCount > 0;
}
