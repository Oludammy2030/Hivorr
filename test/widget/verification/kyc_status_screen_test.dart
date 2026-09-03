import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/systems/verification/screens/kyc_status_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_kyc_remote_data_source.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  KycProvider buildProvider({
    FakeKycRemoteDataSource? remote,
    Duration? pollInterval,
  }) =>
      KycProvider(
        repo: KycRepositoryImpl(remote: remote ?? FakeKycRemoteDataSource()),
        pollInterval: pollInterval ?? const Duration(seconds: 15),
      );

  Future<KycProvider> pumpStatus(
    WidgetTester tester, {
    KycProvider? provider,
    FakeKycRemoteDataSource? remote,
  }) async {
    final KycProvider p = provider ?? buildProvider(remote: remote);
    await pumpApp(
      tester,
      const KycStatusScreen(),
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<KycProvider>.value(value: p),
      ],
    );
    return p;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  group('KycStatusScreen app bar', () {
    testWidgets('renders the KYC title', (WidgetTester tester) async {
      await pumpStatus(tester);
      await settle(tester);
      expect(find.text('KYC Verification'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('KycStatusScreen loading', () {
    testWidgets('shows a loading state while the level is not yet loaded',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource()..blockLevel = true;
      await pumpStatus(tester, remote: remote);
      await tester.pump();
      expect(find.text('Loading KYC status…'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('KycStatusScreen error', () {
    testWidgets('shows an error state with retry after a failed load',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'kyc unavailable',
        );
      await pumpStatus(tester, remote: remote);
      await settle(tester);
      expect(find.text('kyc unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('recovers to content after tapping retry',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'kyc unavailable',
        );
      await pumpStatus(tester, remote: remote);
      await settle(tester);
      expect(find.text('kyc unavailable'), findsOneWidget);

      remote.nextError = null;
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(find.text('kyc unavailable'), findsNothing);
      await unmount(tester);
    });
  });

  group('KycStatusScreen loaded tier_0', () {
    testWidgets('renders the badge and limits for an unverified account',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Cashout'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows the upgrade CTA when a higher tier is reachable',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);

      expect(find.text('Unlock higher limits'), findsOneWidget);
      expect(find.text('Start verification'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('KycStatusScreen loaded tier_3', () {
    testWidgets('hides the upgrade CTA and shows the fully verified state',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_3', status: 'active'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);

      expect(find.text('Unlock higher limits'), findsNothing);
      expect(find.text('Fully verified'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('renders the premium tier badge', (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_3', status: 'active'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('KycStatusScreen loaded tier_1', () {
    testWidgets('renders the verified badge and Active chip',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);

      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('renders the four limit labels', (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(
          tierCode: 'tier_1',
          status: 'active',
          daily: 50000,
          weekly: 200000,
          monthly: 800000,
          cashout: 100000,
        ),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);

      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Cashout'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('KycStatusScreen pull-to-refresh', () {
    testWidgets('refreshes status when the list is pulled down',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);
      final int callsBefore = remote.kycCallCount;

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(remote.kycCallCount, greaterThan(callsBefore));
      await unmount(tester);
    });
  });

  group('KycStatusScreen lifecycle polling', () {
    testWidgets('backgrounding pauses polling; foregrounding resumes it',
        (WidgetTester tester) async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      await pumpStatus(tester, remote: remote);
      await settle(tester);
      final int afterLoad = remote.kycCallCount;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(remote.kycCallCount, lessThanOrEqualTo(afterLoad + 1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 16));
      expect(remote.kycCallCount, greaterThan(afterLoad));
      await unmount(tester);
    });
  });
}
