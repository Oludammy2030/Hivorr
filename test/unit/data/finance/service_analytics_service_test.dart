import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/shared/components/hivorr_mini_bars.dart';
import 'package:hivorr/shared/components/hivorr_month_bars.dart';
import 'package:hivorr/systems/analytics/services/service_analytics_service.dart';

import '../../../support/fakes/finance/fake_earnings_repository.dart';

void main() {
  const ServiceAnalyticsService analytics = ServiceAnalyticsService();

  group('ServiceAnalyticsService.monthBucketsToChartData', () {
    test('maps server buckets to chart data in server order', () {
      final EarningsSummary summary = seedEarningsSummary();

      final List<HivorrMonthDatum> data = analytics.monthBucketsToChartData(
        summary.monthly,
      );

      expect(data, hasLength(6));
      expect(data.first.label, 'May');
      expect(data.first.value, 20000);
      expect(data[2].label, 'Jul');
      expect(data[2].value, 0);
    });

    test('maps an empty window to an empty series (honest empty)', () {
      expect(analytics.monthBucketsToChartData(<EarningsMonthBucket>[]), isEmpty);
    });
  });

  group('ServiceAnalyticsService.groupItemsByContract', () {
    test('groups rows by contract with counts only', () {
      final List<HivorrBarDatum> bars = analytics.groupItemsByContract(
        seedEarningsPage().items,
      );

      expect(bars.map((HivorrBarDatum b) => b.value), contains(1));
      expect(
        bars.where((HivorrBarDatum b) => b.label != 'Other activity'),
        hasLength(1),
      );
      expect(
        bars.where((HivorrBarDatum b) => b.label == 'Other activity'),
        hasLength(1),
      );
    });

    test('maps an empty page to an empty series', () {
      expect(
        analytics.groupItemsByContract(
          seedEarningsPage(items: <EarningsTransaction>[]).items,
        ),
        isEmpty,
      );
    });
  });

  group('ServiceAnalyticsService labels', () {
    test('formats relative and date-time labels without amounts', () {
      final DateTime stamp = DateTime(2026, 10, 1, 12);

      expect(analytics.relativeLabel(stamp), isNotEmpty);
      expect(analytics.dateTimeLabel(stamp), contains('2026'));
    });

    test('exposes twelve month labels', () {
      expect(ServiceAnalyticsService.monthLabels, hasLength(12));
      expect(ServiceAnalyticsService.monthLabels.first, 'Jan');
    });
  });
}
