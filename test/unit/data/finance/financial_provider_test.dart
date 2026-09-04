import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/finance/fake_financial_repository.dart';

void main() {
  FinancialProvider build({
    FakeFinancialRepository? repo,
  }) {
    final r = repo ?? FakeFinancialRepository();
    return FinancialProvider(service: FinancialService(repository: r));
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
    test('starts with no profile, status, or error', () {
      final provider = build();
      expect(provider.profile, isNull);
      expect(provider.status, isNull);
      expect(provider.balances, isEmpty);
      expect(provider.lastError, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isCreating, isFalse);
      expect(provider.isLoaded, isFalse);
      provider.dispose();
    });
  });

  group('load', () {
    test('sets profile and status on success', () async {
      final repo = FakeFinancialRepository(profile: seedProfileEntity());
      final provider = build(repo: repo);
      await provider.load();

      expect(provider.profile, isNotNull);
      expect(provider.status, isNotNull);
      expect(provider.loadState, FinancialLoadState.loaded);
      expect(provider.isLoaded, isTrue);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('when profile is null, no status fetch happens', () async {
      final repo = FakeFinancialRepository()..setProfile(null);
      final provider = build(repo: repo);
      await provider.load();

      expect(provider.profile, isNull);
      expect(provider.status, isNull);
      expect(repo.statusCallCount, 0);
      provider.dispose();
    });

    test('stores error when load fails', () async {
      final repo = FakeFinancialRepository()
        ..setProfile(seedProfileEntity())
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'X9',
        );
      final provider = build(repo: repo);
      // load calls getProfile first; that throws.
      await provider.load();

      expect(provider.loadState, FinancialLoadState.error);
      expect(provider.lastError, isNotNull);
      provider.dispose();
    });
  });

  group('refreshStatus', () {
    test('updates balances from status', () async {
      final repo = FakeFinancialRepository(
        profile: seedProfileEntity(),
        status: seedStatusEntity(
          balances: <Balance>[
            seedBalanceEntity(currencyCode: 'NGN', available: 100),
            seedBalanceEntity(currencyCode: 'USD', available: 200),
          ],
        ),
      );
      final provider = build(repo: repo);
      await provider.refreshStatus();

      expect(provider.balances, hasLength(2));
      expect(provider.balances['NGN']!.availableBalance, 100);
      expect(provider.balances['USD']!.availableBalance, 200);
      provider.dispose();
    });

    test('keeps error when refresh fails', () async {
      final repo = FakeFinancialRepository()
        ..setStatus(seedStatusEntity())
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'X9',
        );
      final provider = build(repo: repo);
      await provider.refreshStatus();

      expect(provider.lastError, isNotNull);
      provider.dispose();
    });
  });

  group('createProfile', () {
    test('delegates and reloads', () async {
      final repo = FakeFinancialRepository();
      final provider = build(repo: repo);
      await provider.createProfile(defaultCurrency: 'NGN');

      expect(repo.createCallCount, 1);
      expect(repo.lastDefaultCurrency, 'NGN');
      expect(provider.profile, isNotNull);
      expect(provider.profile!.defaultCurrency, 'NGN');
      provider.dispose();
    });

    test('stores error on failure', () async {
      final repo = FakeFinancialRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'Unsupported currency',
          code: 'PLT003',
        );
      final provider = build(repo: repo);
      await provider.createProfile(defaultCurrency: 'XYZ');

      expect(provider.lastError, isNotNull);
      expect(provider.lastError!.kind, ApiExceptionKind.validation);
      expect(provider.isCreating, isFalse);
      provider.dispose();
    });
  });

  group('notifications', () {
    test('emits profile_created notification on createProfile', () async {
      final service = FakeNotificationService();
      final repo = FakeFinancialRepository();
      final provider = FinancialProvider(
        service: FinancialService(repository: repo),
        notificationProvider: buildNotifications(service),
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await provider.createProfile(defaultCurrency: 'NGN');
      await pumpEventQueue();

      expect(service.shown, hasLength(1));
      expect(service.shown.single.title, 'Financial profile created');
      expect(service.shown.single.body, 'Your default currency is NGN.');
      expect(service.shown.single.channelId, 'hivorr_default');
      expect(service.shown.single.actionRoute, '/finance');
      expect(service.shown.single.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1000));
      provider.dispose();
    });

    test('does not emit a notification when none is wired', () async {
      final repo = FakeFinancialRepository();
      final provider = build(repo: repo);
      await provider.createProfile(defaultCurrency: 'NGN');
      await pumpEventQueue();
      expect(provider.profile, isNotNull);
      provider.dispose();
    });
  });

  group('polling lifecycle', () {
    test('refreshes status on each poll interval', () {
      fakeAsync((async) {
        final repo = FakeFinancialRepository(
          profile: seedProfileEntity(),
          status: seedStatusEntity(),
        );
        final provider = FinancialProvider(
          service: FinancialService(repository: repo),
          pollInterval: const Duration(seconds: 1),
        );
        unawaited(provider.load());
        async.flushMicrotasks();
        expect(repo.statusCallCount, 1);

        provider.startPolling();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(repo.statusCallCount, greaterThanOrEqualTo(2));

        provider.stopPolling();
        provider.dispose();
      });
    });

    test('pausePolling stops ticks and resumePolling restarts them', () {
      fakeAsync((async) {
        final repo = FakeFinancialRepository(
          profile: seedProfileEntity(),
          status: seedStatusEntity(),
        );
        final provider = FinancialProvider(
          service: FinancialService(repository: repo),
          pollInterval: const Duration(seconds: 1),
        );
        unawaited(provider.load());
        async.flushMicrotasks();
        provider.startPolling();

        provider.pausePolling();
        final countAfterPause = repo.statusCallCount;
        async.elapse(const Duration(seconds: 3));
        expect(repo.statusCallCount, countAfterPause);

        provider.resumePolling();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(repo.statusCallCount, greaterThan(countAfterPause));

        provider.stopPolling();
        provider.dispose();
      });
    });

    test('does not poll while the profile status is terminal', () {
      fakeAsync((async) {
        final repo = FakeFinancialRepository(
          profile: seedProfileEntity(),
          status: seedStatusEntity(profileStatus: 'suspended'),
        );
        final provider = FinancialProvider(
          service: FinancialService(repository: repo),
          pollInterval: const Duration(seconds: 1),
        );
        unawaited(provider.load());
        async.flushMicrotasks();
        final countAfterLoad = repo.statusCallCount;

        provider.startPolling();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(repo.statusCallCount, countAfterLoad);

        provider.stopPolling();
        provider.dispose();
      });
    });
  });
}
