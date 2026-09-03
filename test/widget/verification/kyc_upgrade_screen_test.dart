import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/systems/verification/screens/kyc_upgrade_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_kyc_remote_data_source.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  KycProvider buildProvider({FakeKycRemoteDataSource? remote}) => KycProvider(
        repo: KycRepositoryImpl(remote: remote ?? FakeKycRemoteDataSource()),
      );

  Future<void> pumpUpgrade(
    WidgetTester tester, {
    KycProvider? provider,
    FakeKycRemoteDataSource? remote,
  }) async {
    final KycProvider p = provider ?? buildProvider(remote: remote);
    await pumpApp(
      tester,
      const KycUpgradeScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<KycProvider>.value(value: p),
      ],
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('KycUpgradeScreen app bar', () {
    testWidgets('renders the upgrade title', (WidgetTester tester) async {
      await pumpUpgrade(tester);
      await settle(tester);
      expect(find.text('Upgrade verification'), findsOneWidget);
    });
  });

  group('KycUpgradeScreen loading', () {
    testWidgets('shows a loading state until the level is loaded',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource()..blockLevel = true;
      await pumpUpgrade(tester, remote: remote);
      await tester.pump();
      expect(find.text('Loading upgrade options…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('KycUpgradeScreen error', () {
    testWidgets('shows an error state after a failed load',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'upgrade unavailable',
        );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);
      expect(find.text('upgrade unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('recovers to content after tapping retry',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'upgrade unavailable',
        );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);
      expect(find.text('upgrade unavailable'), findsOneWidget);

      remote.nextError = null;
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(find.text('upgrade unavailable'), findsNothing);
      expect(find.text('Eligible upgrades'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('KycUpgradeScreen eligible tiers', () {
    testWidgets('lists the next eligible tier for a tier_1 account',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);

      expect(find.text('Eligible upgrades'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows the start verification CTA',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);

      expect(find.text('Start verification'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows the tier code for the next eligible tier',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);

      expect(find.text('tier_2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lists the top tier for a tier_2 account',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_2', status: 'active'),
      );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);

      expect(find.text('Premium'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lists tier_1 as the first tier for a tier_0 account',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);

      expect(find.text('Basic'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('KycUpgradeScreen max tier', () {
    testWidgets('shows the max-tier note and no CTA for tier_3',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_3', status: 'active'),
      );
      await pumpUpgrade(tester, remote: remote);
      await settle(tester);

      expect(find.text('You are already at the highest available tier.'),
          findsOneWidget);
      expect(find.text('Start verification'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
