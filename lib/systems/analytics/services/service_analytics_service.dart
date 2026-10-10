import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/shared/components/hivorr_mini_bars.dart'
    show HivorrBarDatum;
import 'package:hivorr/shared/components/hivorr_month_bars.dart'
    show HivorrMonthDatum;
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';

/// Display-formatting seam for server-aggregated earnings (EP-03-16).
///
/// First real implementation in `lib/systems/analytics/` (previously only
/// `.gitkeep`). Formats RPC aggregates into chart-ready data and groups
/// already-paginated rows for breakdowns. Explicitly forbidden: summing
/// `amount` to derive balances or settlement — inputs are server totals and
/// outputs are presentation groupings with counts; the ledger RPCs remain
/// the sole aggregation authority (AGENT.md Rule 4).
class ServiceAnalyticsService {
  const ServiceAnalyticsService();

  /// Short English month labels indexed by month number (1-based).
  static const List<String> monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Maps server month buckets into [HivorrMonthDatum] chart data.
  ///
  /// Buckets pass through in server order; values are display-rounded
  /// server totals (never recomputed from rows).
  List<HivorrMonthDatum> monthBucketsToChartData(
    List<EarningsMonthBucket> buckets,
  ) => <HivorrMonthDatum>[
    for (final EarningsMonthBucket bucket in buckets)
      HivorrMonthDatum(
        label: _monthLabel(bucket.month),
        value: bucket.earned.round(),
      ),
  ];

  /// Groups already-paginated [items] by attributed contract for the
  /// per-contract breakdown.
  ///
  /// Returns release counts per contract label (`Contract …last4`);
  /// unattributed rows group under `Other activity`. Grouping only — no
  /// amount aggregation.
  List<HivorrBarDatum> groupItemsByContract(
    List<EarningsTransaction> items,
  ) {
    final Map<String, int> counts = <String, int>{};
    final Map<String, String> labels = <String, String>{};
    for (final EarningsTransaction item in items) {
      final String? contractId = item.contractId;
      final String key = contractId ?? 'other';
      counts[key] = (counts[key] ?? 0) + 1;
      labels[key] = contractId == null
          ? 'Other activity'
          : 'Contract ${contractId.length <= 4 ? contractId : contractId.substring(contractId.length - 4)}';
    }
    final List<String> keys = counts.keys.toList()..sort();
    return <HivorrBarDatum>[
      for (final String key in keys)
        HivorrBarDatum(label: labels[key] ?? key, value: counts[key] ?? 0),
    ];
  }

  /// Formats [timestamp] as a relative label (`3 hours ago`).
  String relativeLabel(DateTime timestamp) =>
      HivorrFormatters.relative(timestamp);

  /// Formats [timestamp] as a full date-time (`26 Aug 2026, 14:30`).
  String dateTimeLabel(DateTime timestamp) =>
      HivorrFormatters.dateTime(timestamp);

  static String _monthLabel(DateTime month) {
    if (month.month < 1 || month.month > 12) return '';
    return monthLabels[month.month - 1];
  }
}
