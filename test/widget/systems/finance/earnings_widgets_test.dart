import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/shared/components/hivorr_month_bars.dart';
import 'package:hivorr/systems/analytics/services/service_analytics_service.dart';
import 'package:hivorr/systems/finance/widgets/earnings_summary_header.dart';
import 'package:hivorr/systems/finance/widgets/earnings_transaction_tile.dart';
import 'package:hivorr/systems/finance/widgets/monthly_earnings_section.dart';

import '../../../support/fakes/finance/fake_earnings_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  const ServiceAnalyticsService analytics = ServiceAnalyticsService();

  group('EarningsSummaryHeader', () {
    testWidgets('renders server figures with the verified caption', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        EarningsSummaryHeader(summary: seedEarningsSummary()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('In escrow'), findsOneWidget);
      expect(find.text('Lifetime earned'), findsOneWidget);
      expect(find.textContaining('50,000'), findsWidgets);
      expect(find.text('Server-verified figures'), findsOneWidget);
      expect(find.text('Across 2 contracts'), findsOneWidget);
    });
  });

  group('EarningsTransactionTile', () {
    testWidgets('renders an inbound release with contract reference', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        EarningsTransactionTile(
          transaction: seedEarningsTransaction(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Milestone payment'), findsOneWidget);
      expect(find.textContaining('10,000'), findsOneWidget);
      expect(find.textContaining('***ct-1'), findsOneWidget);
      expect(find.textContaining('active'), findsOneWidget);
    });

    testWidgets('flags disputed rows with the frozen badge', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        EarningsTransactionTile(
          transaction: seedEarningsTransaction(escrowStatus: 'disputed'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frozen'), findsOneWidget);
    });

    testWidgets('renders withdrawals without a contract tap target', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await pumpApp(
        tester,
        EarningsTransactionTile(
          transaction: seedEarningsTransaction(
            type: 'withdrawal',
            direction: 'out',
            contractId: null,
          ),
          onTap: () => tapped = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Withdrawal'), findsOneWidget);
      await tester.tap(find.byType(EarningsTransactionTile));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
    });
  });

  group('MonthlyEarningsSection', () {
    testWidgets('renders server buckets with values and labels', (
      WidgetTester tester,
    ) async {
      final List<HivorrMonthDatum> data = analytics.monthBucketsToChartData(
        seedEarningsSummary().monthly,
      );
      await pumpApp(
        tester,
        MonthlyEarningsSection(analytics: analytics, chartData: data),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly earnings'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);
      expect(find.text('20000'), findsOneWidget);
    });

    testWidgets('renders the honest empty label without buckets', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        const MonthlyEarningsSection(
          analytics: analytics,
          chartData: <HivorrMonthDatum>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No earnings yet.'), findsOneWidget);
    });
  });
}
