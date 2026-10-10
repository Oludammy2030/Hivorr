import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/sync/sync_status.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/systems/finance/widgets/earnings_notices.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_kyc_remote_data_source.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  KycProvider tierProvider(String tierCode) {
    final KycProvider provider = KycProvider(
      repo: KycRepositoryImpl(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: tierCode),
        ),
      ),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  group('EarningsKycUpsell', () {
    testWidgets('hides without a KYC provider mounted', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const EarningsKycUpsell());
      await tester.pumpAndSettle();

      expect(
        find.text('Verify your identity to withdraw'),
        findsNothing,
      );
    });

    testWidgets('shows for an unverified tier without blocking reads', (
      WidgetTester tester,
    ) async {
      final KycProvider kyc = tierProvider('tier_0');
      await kyc.load();
      await pumpApp(
        tester,
        const EarningsKycUpsell(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<KycProvider>.value(value: kyc),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Verify your identity to withdraw'),
        findsOneWidget,
      );
      expect(find.text('Verify identity'), findsOneWidget);
    });

    testWidgets('hides for a verified tier', (WidgetTester tester) async {
      final KycProvider kyc = tierProvider('tier_1');
      await kyc.load();
      await pumpApp(
        tester,
        const EarningsKycUpsell(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<KycProvider>.value(value: kyc),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Verify your identity to withdraw'),
        findsNothing,
      );
    });
  });

  group('EarningsOfflineBanner', () {
    testWidgets('hides without a sync provider mounted', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const EarningsOfflineBanner());
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('hides while online', (WidgetTester tester) async {
      final SyncStatusProvider sync = SyncStatusProvider();
      addTearDown(sync.dispose);
      await pumpApp(
        tester,
        const EarningsOfflineBanner(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<SyncStatusProvider>.value(value: sync),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('shows the cached-window notice when offline', (
      WidgetTester tester,
    ) async {
      final SyncStatusProvider sync = SyncStatusProvider();
      addTearDown(sync.dispose);
      sync.setStatus(SyncStatus.offline);
      await pumpApp(
        tester,
        const EarningsOfflineBanner(),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<SyncStatusProvider>.value(value: sync),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You are offline — showing your last synced earnings.'),
        findsOneWidget,
      );
    });
  });
}
