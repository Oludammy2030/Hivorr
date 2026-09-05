import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/finance/fake_conversion_repository.dart';
import '../../../support/fakes/finance/fake_financial_repository.dart';

/// Unit coverage for [ConversionProvider] (EP-02-15 §5.6): pair/amount
/// selection, the trusted-rate lifecycle (`loadRate`/`refreshPreview`), local
/// estimate + execution, the one-shot notification hook, the history load with
/// its lifecycle gate, and the `WidgetsBindingObserver` pause guard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ConversionProvider build({
    FakeConversionRepository? repo,
    WalletConversionPairsConfig? pairsConfig,
    FakeFinancialRepository? financial,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  }) {
    final r = repo ?? FakeConversionRepository();
    return ConversionProvider(
      service: ConversionService(
        repository: r,
        pairsConfig:
            pairsConfig ??
            const WalletConversionPairsConfig(
              enabled: true,
              baseCrossRates: <String, double>{
                'NGN|USD': 0.0007,
              },
            ),
      ),
      financialService: financial == null
          ? null
          : FinancialService(repository: financial),
      notificationProvider: notificationProvider,
      clock: clock,
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

  FakeConversionRepository seededRepo() => (FakeConversionRepository()
        ..setRate('NGN', 'USD', 0.0007)
        ..setRate('USD', 'NGN', 1428.5714285714287));

  const ApiException insufficientBalance = ApiException(
    kind: ApiExceptionKind.conflict,
    message: 'Insufficient source balance.',
    code: 'PLT006',
  );

  group('initial state', () {
    test('starts idle with no selection, no rate, and no error', () {
      final provider = build();
      expect(provider.loadState, ConversionLoadState.idle);
      expect(provider.fromCurrency, isNull);
      expect(provider.toCurrency, isNull);
      expect(provider.amount, 0);
      expect(provider.rate, isNull);
      expect(provider.isRateLoading, isFalse);
      expect(provider.isRateUnavailable, isFalse);
      expect(provider.preview, isNull);
      expect(provider.lastConversion, isNull);
      expect(provider.history, isEmpty);
      expect(provider.lastError, isNull);
      expect(provider.canConvert, isFalse);
      expect(provider.isConversionEnabled, isTrue);
      provider.dispose();
    });

    test('isConversionEnabled is false while flag-gated off', () {
      final provider = build(pairsConfig: const WalletConversionPairsConfig());
      expect(provider.isConversionEnabled, isFalse);
      expect(provider.availablePairs, isEmpty);
      provider.dispose();
    });
  });

  group('selection', () {
    test('setSource/setDestination record the directed pair', () {
      final provider = build();
      provider.setSource('NGN');
      provider.setDestination('USD');
      expect(provider.fromCurrency, 'NGN');
      expect(provider.toCurrency, 'USD');
      expect(provider.canConvert, isFalse); // amount still 0
      provider.dispose();
    });

    test('setAmount drives canConvert once a valid pair is chosen', () {
      final provider = build();
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);
      expect(provider.canConvert, isTrue);
      expect(provider.amount, 50000);
      provider.dispose();
    });

    test('a self-pair is never convertible', () {
      final provider = build();
      provider.setSource('NGN');
      provider.setDestination('NGN');
      provider.setAmount(50000);
      expect(provider.canConvert, isFalse);
      provider.dispose();
    });
  });

  group('loadRate', () {
    test('fetches the trusted rate for the selected pair', () async {
      final repo = seededRepo();
      final provider = build(repo: repo);
      provider.setSource('NGN');
      provider.setDestination('USD');

      await provider.loadRate();

      expect(provider.rate, 0.0007);
      expect(provider.isRateLoading, isFalse);
      expect(provider.isRateUnavailable, isFalse);
      expect(repo.getRateCallCount, 1);
      expect(repo.lastFromCurrency, 'NGN');
      expect(repo.lastToCurrency, 'USD');
      provider.dispose();
    });

    test('returns early without a complete valid pair', () async {
      final repo = seededRepo();
      final provider = build(repo: repo);
      provider.setSource('NGN');

      await provider.loadRate();

      expect(repo.getRateCallCount, 0);
      expect(provider.rate, isNull);
      provider.dispose();
    });

    test('surfaces the rate-unavailable state when no configured rate exists',
        () async {
      final repo = FakeConversionRepository();
      final provider = build(repo: repo);
      provider.setSource('NGN');
      provider.setDestination('USD');

      await provider.loadRate();

      expect(provider.isRateUnavailable, isTrue);
      expect(provider.rate, isNull);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('stores a generic ApiException failure on the error slot', () async {
      final repo = seededRepo()
        ..nextError = insufficientBalance;
      final provider = build(repo: repo);
      provider.setSource('NGN');
      provider.setDestination('USD');

      await provider.loadRate();

      expect(provider.lastError, same(insufficientBalance));
      expect(provider.rate, isNull);
      expect(provider.isRateLoading, isFalse);
      provider.dispose();
    });
  });

  group('refreshPreview', () {
    test('computes a local estimate and records the trusted rate', () async {
      final repo = seededRepo();
      final provider = build(repo: repo);
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);

      await provider.refreshPreview();

      expect(provider.preview, isNotNull);
      expect(provider.preview!.fromAmount, 50000);
      expect(provider.preview!.grossAmount, closeTo(35, 1e-9));
      expect(provider.preview!.toAmount, closeTo(35, 1e-9));
      expect(provider.preview!.exchangeRate, 0.0007);
      expect(provider.rate, 0.0007);
      expect(provider.isRateUnavailable, isFalse);
      expect(repo.previewCallCount, 1);
      provider.dispose();
    });

    test('amount edits preserve the trusted rate while clearing the preview',
        () async {
      final repo = seededRepo();
      final provider = build(repo: repo);
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);
      await provider.refreshPreview();

      provider.setAmount(75000);

      expect(provider.preview, isNull);
      expect(provider.rate, 0.0007);
      provider.dispose();
    });

    test('clears the preview and stores the error on failure', () async {
      final repo = seededRepo()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'estimate down',
          code: 'PLT999',
        );
      final provider = build(repo: repo);
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);

      await provider.refreshPreview();

      expect(provider.preview, isNull);
      expect(provider.lastError, isNotNull);
      provider.dispose();
    });
  });

  group('execute', () {
    test('records the conversion and refreshes balances via FinancialService',
        () async {
      final repo = seededRepo()
        ..setConversion(seedConversionEntity(id: 'conversion-foo', toAmount: 35));
      final financial = FakeFinancialRepository();
      final provider = build(repo: repo, financial: financial);
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);
      await provider.refreshPreview();

      await provider.execute();

      expect(provider.lastConversion, isNotNull);
      expect(provider.lastConversion!.id, 'conversion-foo');
      expect(provider.lastConversion!.status, 'completed');
      expect(repo.executeCallCount, 1);
      expect(financial.statusCallCount, 1);
      expect(provider.lastError, isNull);
      provider.dispose();
    });

    test('surfaces PLT006 as a conflict error without a notification',
        () async {
      final repo = seededRepo()
        ..nextError = insufficientBalance;
      final FakeNotificationService service = FakeNotificationService();
      final NotificationProvider notifications = buildNotifications(service);
      final provider = build(
        repo: repo,
        notificationProvider: notifications,
      );
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);

      await provider.execute();

      expect(provider.lastError, same(insufficientBalance));
      expect(provider.lastConversion, isNull);
      expect(service.shown, isEmpty);
      provider.dispose();
    });

    test('emits a one-shot Currency converted notification on success',
        () async {
      final repo = seededRepo()
        ..setConversion(seedConversionEntity(id: 'conversion-notify'));
      final FakeNotificationService service = FakeNotificationService();
      final NotificationProvider notifications = buildNotifications(service);
      final DateTime fixed = DateTime.utc(2026, 1, 1);
      final provider = build(
        repo: repo,
        notificationProvider: notifications,
        clock: () => fixed,
      );
      provider.setSource('NGN');
      provider.setDestination('USD');
      provider.setAmount(50000);

      await provider.execute();
      // The notification hook is fire-and-forget; flush the microtask queue.
      await Future<void>.delayed(Duration.zero);

      expect(service.shown, hasLength(1));
      final HivorrNotification n = service.shown.single;
      expect(n.title, 'Currency converted');
      expect(n.body, contains('₦50,000.00'));
      expect(n.body, contains('\u2192'));
      expect(n.body, contains('\$35.00'));
      expect(n.actionRoute, '/finance/convert');
      expect(n.timestamp, fixed);
      provider.dispose();
    });
  });

  group('loadHistory', () {
    test('loads history rows into the provider', () async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[
          seedConversionEntity(id: 'c-1'),
          seedConversionEntity(id: 'c-2'),
        ],
      );
      final provider = build(repo: repo);

      await provider.loadHistory();

      expect(provider.loadState, ConversionLoadState.loaded);
      expect(provider.isLoading, isFalse);
      expect(provider.history, hasLength(2));
      expect(provider.history.first.id, 'c-1');
      expect(repo.historyCallCount, 1);
      provider.dispose();
    });

    test('stores the error and enters error state on failure', () async {
      final repo = FakeConversionRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'history down',
          code: 'PLT999',
        );
      final provider = build(repo: repo);

      await provider.loadHistory();

      expect(provider.loadState, ConversionLoadState.error);
      expect(provider.history, isEmpty);
      expect(provider.lastError, isNotNull);
      provider.dispose();
    });

    test('skips the load while the app is backgrounded', () async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[seedConversionEntity()],
      );
      final provider = build(repo: repo);
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);

      await provider.loadHistory();
      await provider.loadHistory();

      expect(repo.historyCallCount, 0);
      expect(provider.history, isEmpty);
      provider.dispose();
    });

    test('resumes refreshing when the app is foregrounded', () async {
      final repo = FakeConversionRepository(
        history: <CurrencyConversion>[seedConversionEntity()],
      );
      final provider = build(repo: repo);
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      await provider.loadHistory();
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await provider.loadHistory();

      expect(repo.historyCallCount, 1);
      expect(provider.history, hasLength(1));
      provider.dispose();
    });
  });
}