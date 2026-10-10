import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';

import '../../../support/fakes/fake_notifications.dart';
import '../../../support/fakes/finance/fake_earnings_repository.dart';

ServiceEarningsService _service(FakeEarningsRepository repository) =>
    ServiceEarningsService(repository: repository);

void main() {
  group('EarningsProvider', () {
    test('loads the summary for the selected currency', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setSummary('NGN', seedEarningsSummary());
      final EarningsProvider provider = EarningsProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);

      await provider.load();

      expect(provider.loadState, EarningsLoadState.loaded);
      expect(provider.summary?.lifetimeEarned, 120000);
      expect(provider.currency, 'NGN');
      expect(repository.summaryCallCount, 1);
    });

    test('switches currency and loads the new window', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setSummary('NGN', seedEarningsSummary());
      repository.setSummary(
        'USD',
        seedEarningsSummary(currencyCode: 'USD', lifetimeEarned: 500),
      );
      final EarningsProvider provider = EarningsProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);

      await provider.load();
      await provider.setCurrency('USD');

      expect(provider.currency, 'USD');
      expect(provider.summary?.lifetimeEarned, 500);
    });

    test('keeps prior data and records the error on refresh failure', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setSummary('NGN', seedEarningsSummary());
      final EarningsProvider provider = EarningsProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);
      await provider.load();

      repository.nextError = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'offline',
      );
      await provider.refresh();

      expect(provider.summary, isNotNull);
      expect(provider.loadState, EarningsLoadState.loaded);
      expect(provider.lastError, isNotNull);
    });

    test('moves to error when the first load fails with nothing cached',
        () async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.nextError = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'offline',
      );
      final EarningsProvider provider = EarningsProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);

      await provider.load();

      expect(provider.loadState, EarningsLoadState.error);
      expect(provider.summary, isNull);
    });

    test('notifies a release, invalidates cache, and refreshes', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setSummary('NGN', seedEarningsSummary());
      final EarningsProvider provider = EarningsProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);
      await provider.load();

      await provider.notifyEarningsReleased(
        contractId: 'contract-1',
        milestoneId: 'ms-1',
      );

      expect(repository.invalidateCallCount, 1);
      expect(provider.summary, isNotNull);
    });

    test('notifies a release with a Payment received notification', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final FakeEarningsRepository repository = FakeEarningsRepository();
      repository.setSummary('NGN', seedEarningsSummary());
      final FakeNotificationService notifications =
          FakeNotificationService();
      final EarningsProvider provider = EarningsProvider(
        service: _service(repository),
        notificationProvider: NotificationProvider(
          notifications,
          NotificationPermissionManager(
            platform: FakeNotificationPermissionPlatform(
              nextStatus: NotificationPermissionStatus.granted,
            ),
          ),
        ),
      );
      addTearDown(provider.dispose);
      await provider.load();

      await provider.notifyEarningsReleased(
        contractId: 'contract-1',
        milestoneId: 'ms-1',
      );

      expect(notifications.shown, hasLength(1));
      final HivorrNotification n = notifications.shown.single;
      expect(n.title, 'Payment received');
      expect(n.actionRoute, '/dashboard/earnings');
      expect(n.body, isNot(contains('120000')));
    });
  });

  group('TransactionHistoryProvider', () {
    test('loads the first page in server order', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository(
        page: seedEarningsPage(),
      );
      final TransactionHistoryProvider provider = TransactionHistoryProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);

      await provider.load();

      expect(provider.loadState, TransactionHistoryLoadState.loaded);
      expect(provider.items.map((e) => e.id), <String>['tx-1', 'tx-2']);
      expect(provider.hasMore, isFalse);
    });

    test('setType reloads from the first page with the new filter', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository(
        page: seedEarningsPage(),
      );
      final TransactionHistoryProvider provider = TransactionHistoryProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);
      await provider.load();

      await provider.setType(EarningsHistoryFilter.earned);

      expect(provider.typeFilter, EarningsHistoryFilter.earned);
      expect(repository.lastType, EarningsHistoryFilter.earned);
    });

    test('accumulates cursor pages without re-sorting', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository(
        page: seedEarningsPage(
          hasMore: true,
          nextCursor: <String, dynamic>{
            'created_at': '2026-10-01T12:00:00.000Z',
            'id': 'tx-2',
          },
        ),
      );
      final TransactionHistoryProvider provider = TransactionHistoryProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);
      await provider.load();
      final int firstCount = provider.items.length;

      repository.setPage(seedEarningsPage());
      await provider.loadMore();

      expect(provider.items.length, firstCount + 2);
      expect(provider.items.first.id, 'tx-1');
    });

    test('clearFilters restores defaults and reloads', () async {
      final FakeEarningsRepository repository = FakeEarningsRepository(
        page: seedEarningsPage(),
      );
      final TransactionHistoryProvider provider = TransactionHistoryProvider(
        service: _service(repository),
      );
      addTearDown(provider.dispose);
      await provider.setType(EarningsHistoryFilter.withdrawn);

      await provider.clearFilters();

      expect(provider.typeFilter, EarningsHistoryFilter.all);
      expect(provider.contractId, isNull);
    });
  });
}
