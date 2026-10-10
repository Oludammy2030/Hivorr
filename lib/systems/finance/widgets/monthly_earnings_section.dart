import 'package:flutter/material.dart';

import 'package:hivorr/shared/components/hivorr_month_bars.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/analytics/services/service_analytics_service.dart';

/// Trailing-month earnings chart section (EP-03-16).
///
/// Renders server month buckets via [HivorrMonthBars] inside a [HivorrCard];
/// empty windows show the honest `No earnings yet` empty label (never
/// invented bars). Buckets arrive pre-aggregated from
/// `service_earnings_summary`; [ServiceAnalyticsService] maps them to chart
/// data without recomputing settlement. Uses only [AppTheme] tokens
/// (AGENT.md Rule 5).
class MonthlyEarningsSection extends StatelessWidget {
  const MonthlyEarningsSection({
    super.key,
    required this.analytics,
    required this.chartData,
  });

  /// Display-formatting seam (injected for testability).
  final ServiceAnalyticsService analytics;

  /// Chart-ready server buckets (pass-through, verbatim order).
  final List<HivorrMonthDatum> chartData;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Monthly earnings', style: context.textTheme.titleMedium),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrMonthBars(items: chartData, emptyLabel: 'No earnings yet.'),
        ],
      ),
    );
  }
}
