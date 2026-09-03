import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/integrations/kyc/kyc_provider_registry.dart';
import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/integrations/kyc/mock_kyc_provider.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

import '../../../support/fakes/fake_kyc_remote_data_source.dart';
import '../../../support/fakes/fake_notifications.dart';

void main() {
  KycProvider build({
    FakeKycRemoteDataSource? remote,
    KycProviderRegistry? registry,
    NotificationProvider? notifications,
    Duration? pollInterval,
  }) {
    final repo = KycRepositoryImpl(
      remote: remote ?? FakeKycRemoteDataSource(),
      providerRegistry: registry,
    );
    return KycProvider(
      repo: repo,
      notificationProvider: notifications,
      pollInterval: pollInterval,
    );
  }

  NotificationProvider buildNotifications(FakeNotificationService service) =>
      NotificationProvider(
        service,
        NotificationPermissionManager(
          platform: FakeNotificationPermissionPlatform(
            nextStatus: NotificationPermissionStatus.granted,
          ),
        ),
      );

  group('initial state', () {
    test('starts idle with no snapshot', () {
      final provider = build();
      expect(provider.loadState, KycLoadState.idle);
      expect(provider.kycLevel, isNull);
      expect(provider.currentTier, KycTier.tier0);
      expect(provider.nextEligibleTier, isNull);
      provider.dispose();
    });
  });

  group('load', () {
    test('loads level + limits + status in parallel', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(
          tierCode: 'tier_1',
          status: 'active',
          daily: 500000,
          weekly: 2000000,
          monthly: 8000000,
          cashout: 1000000,
        ),
      );
      final provider = build(remote: remote);

      await provider.load();

      expect(provider.loadState, KycLoadState.loaded);
      expect(provider.kycLevel!.tierCode, 'tier_1');
      expect(provider.currentTier, KycTier.tier1);
      expect(provider.limits!.cashout, 1000000);
      expect(remote.kycCallCount, 1);
      expect(remote.limitsCallCount, 1);
      expect(remote.statusCallCount, 1);
      provider.dispose();
    });

    test('enters error state on a failing remote', () async {
      final remote = FakeKycRemoteDataSource()..nextError = const ApiException(
            kind: ApiExceptionKind.server,
            message: 'boom',
          );
      final provider = build(remote: remote);

      await provider.load();

      expect(provider.loadState, KycLoadState.error);
      expect(provider.lastError, isA<ApiException>());
      provider.dispose();
    });
  });

  group('nextEligibleTier', () {
    test('returns tier1 from tier0', () async {
      final provider = build();
      await provider.load();
      expect(provider.nextEligibleTier, KycTier.tier1);
      provider.dispose();
    });

    test('returns null at tier3', () async {
      final provider = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_3', status: 'active'),
          statusResult: seedKycStatusDto(tierCode: 'tier_3'),
        ),
      );
      await provider.load();
      expect(provider.nextEligibleTier, isNull);
      provider.dispose();
    });
  });

  group('requestUpgrade', () {
    test('delegates to the repository and updates state', () async {
      final mock = MockKycProvider(
        result: const KycVerificationResult(status: 'pending'),
      );
      final provider = build(
        registry: KycProviderRegistry(primary: mock),
      );

      final result = await provider.requestUpgrade(targetTier: KycTier.tier1);

      expect(mock.lastTargetTier, KycTier.tier1);
      expect(result, isNotNull);
      provider.dispose();
    });

    test('surfaces a validation error without crashing', () async {
      final provider = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
        ),
      );

      final result = await provider.requestUpgrade(targetTier: KycTier.tier1);

      expect(result, isNull);
      expect(provider.lastError, isA<ApiException>()
          .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.validation));
      provider.dispose();
    });
  });

  group('polling', () {
    test('startPolling ticks after the interval', () {
      fakeAsync((FakeAsync async) {
        final remote = FakeKycRemoteDataSource();
        final provider = build(
          remote: remote,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        final callsAtStart = remote.kycCallCount;

        async.elapse(const Duration(seconds: 14));
        expect(remote.kycCallCount, callsAtStart);

        async.elapse(const Duration(seconds: 1));
        expect(remote.kycCallCount, greaterThan(callsAtStart));
        provider.dispose();
      });
    });

    test('stopPolling prevents further refreshes', () {
      fakeAsync((FakeAsync async) {
        final remote = FakeKycRemoteDataSource();
        final provider = build(
          remote: remote,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        provider.stopPolling();
        final countAfterStop = remote.kycCallCount;

        async.elapse(const Duration(seconds: 60));
        expect(remote.kycCallCount, countAfterStop);
        provider.dispose();
      });
    });

    test('pausePolling stops and resumePolling restarts', () {
      fakeAsync((FakeAsync async) {
        final remote = FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
        );
        final provider = build(
          remote: remote,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();
        provider.pausePolling();
        final countAfterPause = remote.kycCallCount;

        async.elapse(const Duration(seconds: 60));
        expect(remote.kycCallCount, countAfterPause);

        provider.resumePolling();
        async.elapse(const Duration(seconds: 15));
        expect(remote.kycCallCount, greaterThan(countAfterPause));
        provider.dispose();
      });
    });
  });

  group('tier upgrade notification', () {
    test('emits a single high-priority notification on an upgrade', () async {
      final service = FakeNotificationService();
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'active'),
      );
      final provider = build(remote: remote, notifications: buildNotifications(service));

      // Baseline established at tier_0 — no notification yet.
      await provider.refreshStatus();
      expect(service.shown, isEmpty);

      // Server authorizes an upgrade to tier_1.
      remote.kycResult = seedKycDto(tierCode: 'tier_1', status: 'active');
      await provider.refreshStatus();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.title, contains('Verification upgraded'));
      provider.dispose();
    });
  });

  group('load lifecycle', () {
    test('surfaces loading state while a load is in flight', () async {
      final provider = build();
      KycLoadState? observed;
      provider.addListener(() {
        if (provider.loadState == KycLoadState.loading) observed = provider.loadState;
      });

      await provider.load();

      expect(observed, KycLoadState.loading);
      expect(provider.loadState, KycLoadState.loaded);
      provider.dispose();
    });

    test('currentTier and nextEligibleTier reflect loaded data', () async {
      final provider = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
        ),
      );
      await provider.load();

      expect(provider.currentTier, KycTier.tier1);
      expect(provider.nextEligibleTier, KycTier.tier2);
      provider.dispose();
    });
  });

  group('requestUpgrade state', () {
    test('updates kycLevel and notifies on a resolved upgrade', () async {
      final provider = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
        ),
      );
      await provider.load();

      final KycLevel? next =
          await provider.requestUpgrade(targetTier: KycTier.tier1);

      expect(provider.kycLevel, isNotNull);
      expect(provider.lastError, isNull);
      expect(next, isNotNull);
      provider.dispose();
    });
  });

  group('polling terminal', () {
    test('auto-stops polling once the assignment is no longer pending', () {
      fakeAsync((FakeAsync async) {
        final remote = FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
        );
        final provider = build(
          remote: remote,
          pollInterval: const Duration(seconds: 15),
        );
        provider.startPolling();

        // First tick sees pending (keeps polling), then flips to active.
        remote.kycResult = seedKycDto(tierCode: 'tier_1', status: 'active');
        async.elapse(const Duration(seconds: 15));
        final countAfterActive = remote.kycCallCount;

        async.elapse(const Duration(seconds: 60));
        expect(
          remote.kycCallCount,
          countAfterActive,
          reason: 'timer cancels on terminal active status',
        );
        provider.dispose();
      });
    });
  });

  group('refresh error', () {
    test('records an ApiException and clears isRefreshing', () async {
      final remote = FakeKycRemoteDataSource();
      final provider = build(remote: remote);
      await provider.load();
      remote.nextError = const ApiException(
        kind: ApiExceptionKind.server,
        message: 'boom',
      );

      await provider.refreshStatus();

      expect(provider.lastError, isA<ApiException>());
      expect(provider.isRefreshing, isFalse);
      provider.dispose();
    });
  });
}
