/// Data Transfer Object for the earnings summary read model (EP-03-16).
///
/// Mirrors the `service_earnings_summary` RPC envelope `data` object
/// (`supabase/migrations/20261008090001_service_earnings_visibility.sql`).
class EarningsSummaryDto {
  const EarningsSummaryDto({
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

  factory EarningsSummaryDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMonthly =
        (json['monthly'] as List<dynamic>?) ?? <dynamic>[];
    return EarningsSummaryDto(
      currencyCode: (json['currency_code'] as String?) ?? '',
      availableBalance: _toDouble(json['available_balance']),
      heldBalance: _toDouble(json['held_balance']),
      pendingBalance: _toDouble(json['pending_balance']),
      lifetimeEarned: _toDouble(json['lifetime_earned']),
      releaseCount: _toInt(json['release_count']),
      completedContracts: _toInt(json['completed_contracts']),
      totalWithdrawn: _toDouble(json['total_withdrawn']),
      frozenCount: _toInt(json['frozen_count']),
      monthly: rawMonthly
          .whereType<Map<String, dynamic>>()
          .map(EarningsMonthBucketDto.fromJson)
          .toList(growable: false),
    );
  }

  final String currencyCode;
  final double availableBalance;
  final double heldBalance;
  final double pendingBalance;
  final double lifetimeEarned;
  final int releaseCount;
  final int completedContracts;
  final double totalWithdrawn;
  final int frozenCount;
  final List<EarningsMonthBucketDto> monthly;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.truncate();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// DTO for one trailing-month bucket of the summary payload (EP-03-16).
class EarningsMonthBucketDto {
  const EarningsMonthBucketDto({
    required this.month,
    required this.earned,
    required this.releaseCount,
  });

  factory EarningsMonthBucketDto.fromJson(Map<String, dynamic> json) {
    final dynamic rawMonth = json['month'];
    DateTime month = DateTime.fromMillisecondsSinceEpoch(0);
    if (rawMonth is DateTime) {
      month = rawMonth;
    } else if (rawMonth is String) {
      month = DateTime.tryParse(rawMonth) ?? month;
    }
    return EarningsMonthBucketDto(
      month: month,
      earned: EarningsSummaryDto._toDouble(json['earned']),
      releaseCount: EarningsSummaryDto._toInt(json['count']),
    );
  }

  final DateTime month;
  final double earned;
  final int releaseCount;
}
