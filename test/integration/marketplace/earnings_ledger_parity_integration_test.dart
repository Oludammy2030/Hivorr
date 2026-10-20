// Run: flutter test test/integration/marketplace/earnings_ledger_parity_integration_test.dart
//
// EP-03-20 VP11 — Earnings ledger parity. Composes the REAL
// ServiceEarningsService + EarningsProvider + TransactionHistoryProvider over
// FakeEarningsRepository (display-only seam — figures pass through verbatim).
//
// DV-02 shared ledger fixture: this test imports the exact seeded constants
// from VP6 (`milestone_release_ledger_integration_test.dart`) so the escrow
// release amount asserted there and the earnings history amount asserted here
// derive from ONE definition — the "ledger parity" the plan asks for. No test
// recomputes either figure (AGENT.md Rule 4: no client-side aggregation).

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';

import '../../support/fakes/finance/fake_earnings_repository.dart';
import 'milestone_release_ledger_integration_test.dart'
    show ledgerContractTotal, ledgerCurrency, ledgerMilestoneAmount;

void main() {
  group('EP-03-20 VP11 — earnings ledger parity', () {
    late FakeEarningsRepository repo;
    late ServiceEarningsService service;

    setUp(() {
      repo = FakeEarningsRepository(
        summaries: <String, EarningsSummary>{
          ledgerCurrency: seedEarningsSummary(
            currencyCode: ledgerCurrency,
            // Available equals one released milestone from the shared fixture
            // (the VP6 release of `ledgerMilestoneAmount`).
            available: ledgerMilestoneAmount,
            held: ledgerContractTotal - ledgerMilestoneAmount,
            lifetimeEarned: ledgerContractTotal,
            releaseCount: 1,
          ),
        },
        page: seedEarningsPage(
          items: <EarningsTransaction>[
            // The history row the ledger carries for the VP6 release.
            seedEarningsTransaction(
              id: 'tx-release-1',
              type: 'escrow_release',
              currencyCode: ledgerCurrency,
              amount: ledgerMilestoneAmount,
              direction: 'in',
              contractId: 'c1',
            ),
            seedEarningsTransaction(
              id: 'tx-withdrawal-1',
              type: 'withdrawal',
              currencyCode: ledgerCurrency,
              amount: 2000,
              direction: 'out',
              contractId: null,
              contractStatus: null,
              escrowStatus: null,
            ),
          ],
        ),
      );
      service = ServiceEarningsService(repository: repo);
    });

    test('DoD-VP11a: history row amount equals the VP6 released amount '
        '(single shared fixture)', () async {
      // Act: fetch the ledger history page through the real service.
      final EarningsTransactionPage page = await service.listHistory(
        currencyCode: ledgerCurrency,
      );

      // Assert: the release row carries exactly the amount VP6 released —
      // both tests read the same const; neither recomputes it.
      expect(page.items, hasLength(2));
      final EarningsTransaction release = page.items.first;
      expect(release.type, 'escrow_release');
      expect(release.amount, ledgerMilestoneAmount);
      expect(release.contractId, 'c1');
      expect(release.currencyCode, ledgerCurrency);
      // The row is read verbatim — the repository call counter proves a
      // single server read, no local fold over the rows.
      expect(repo.historyCallCount, 1);
      expect(repo.lastCurrency, ledgerCurrency);
    });

    test('DoD-VP11b: summary figures pass through verbatim (no client '
        'aggregation)', () async {
      // Act: fetch the server-aggregated summary.
      final EarningsSummary summary = await service.getSummary(ledgerCurrency);

      // Assert: every figure equals the seeded server value exactly — the
      // client never re-derives `available = released - withdrawn` etc.
      expect(summary.availableBalance, ledgerMilestoneAmount);
      expect(summary.heldBalance, ledgerContractTotal - ledgerMilestoneAmount);
      expect(summary.lifetimeEarned, ledgerContractTotal);
      expect(summary.releaseCount, 1);
      expect(summary.currencyCode, ledgerCurrency);
      expect(repo.summaryCallCount, 1);
      expect(repo.lastCurrency, ledgerCurrency);
    });

    test('DoD-VP11c: EarningsProvider surfaces the summary read-only and '
        'invalidates on release notification', () async {
      final EarningsProvider provider = EarningsProvider(
        service: service,
        pollInterval: const Duration(hours: 1),
        clock: () => DateTime.utc(2026, 10, 1),
      );
      addTearDown(provider.dispose);

      // Act: first load + release hook (what EP-03-11 calls after release).
      await provider.load();
      expect(provider.isLoaded, isTrue);
      expect(provider.summary?.availableBalance, ledgerMilestoneAmount);

      await provider.notifyEarningsReleased(
        contractId: 'c1',
        milestoneId: 'm1',
      );

      // Assert: the hook invalidated the cache and refreshed — the summary
      // still mirrors the seeded server figure (no local mutation).
      expect(repo.invalidateCallCount, greaterThanOrEqualTo(1));
      expect(provider.summary?.availableBalance, ledgerMilestoneAmount);
      expect(provider.summary?.currencyCode, ledgerCurrency);
    });

    test(
      'DoD-VP11d: history rows stay in server order (never re-sorted)',
      () async {
        final TransactionHistoryProvider history = TransactionHistoryProvider(
          service: service,
        );
        addTearDown(history.dispose);

        // Act: load the first page.
        await history.load();

        // Assert: verbatim server order — release row before withdrawal row,
        // exactly as the repository returned them.
        expect(history.isLoaded, isTrue);
        expect(
          history.items.map((EarningsTransaction e) => e.id).toList(),
          <String>['tx-release-1', 'tx-withdrawal-1'],
        );
        expect(history.items.first.amount, ledgerMilestoneAmount);
        expect(history.hasMore, isFalse);
      },
    );

    test('DoD-VP11e: unsupported currency surfaces PLT003 (no local '
        'conversion)', () async {
      // Arrange: no summary seeded for XYZ → the server oracle says no.
      await expectLater(
        service.getSummary('XYZ'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      // The service never converts locally — it only asks the repository.
      expect(repo.lastCurrency, 'XYZ');
      expect(ServiceEarningsService.isCurrencySupported('NGN'), isTrue);
      expect(ServiceEarningsService.isCurrencySupported('XYZ'), isFalse);
    });

    test('DoD-VP11f: failed summary keeps the previous window (offline '
        'honesty)', () async {
      final EarningsProvider provider = EarningsProvider(
        service: service,
        pollInterval: const Duration(hours: 1),
        clock: () => DateTime.utc(2026, 10, 1),
      );
      addTearDown(provider.dispose);

      await provider.load();
      expect(provider.summary, isNotNull);

      // Arrange: the next read fails (e.g. transient network).
      repo.nextError = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Network unreachable.',
        code: 'PLT002',
      );

      // Act: a refresh fails but must not blank the visible window.
      await provider.refresh();

      // Assert: stale-but-honest window retained, error surfaced read-only.
      expect(provider.summary, isNotNull);
      expect(provider.summary?.availableBalance, ledgerMilestoneAmount);
      expect(provider.lastError, isNotNull);
      expect(provider.lastError!.code, 'PLT002');
    });
  });
}
