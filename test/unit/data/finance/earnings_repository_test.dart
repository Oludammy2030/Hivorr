import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/local/earnings_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/earnings_remote_data_source.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/data/repositories/earnings_repository_impl.dart';

class _FakeRemote implements EarningsRemoteDataSource {
  _FakeRemote({this.summary, this.page, this.error});

  EarningsSummaryDto? summary;
  EarningsTransactionPageDto? page;
  ApiException? error;
  int summaryCalls = 0;
  int historyCalls = 0;
  Map<String, dynamic>? lastFilters;

  @override
  Future<EarningsSummaryDto> getSummary(String currencyCode) async {
    summaryCalls++;
    if (error != null) throw error!;
    return summary!;
  }

  @override
  Future<EarningsTransactionPageDto> listTransactions({
    required String currencyCode,
    String type = 'all',
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  }) async {
    historyCalls++;
    lastFilters = <String, dynamic>{
      'currencyCode': currencyCode,
      'type': type,
      'contractId': contractId,
      'limit': limit,
      'cursor': cursor,
    };
    if (error != null) throw error!;
    return page!;
  }
}

EarningsSummaryDto _summaryDto() => EarningsSummaryDto.fromJson(
  <String, dynamic>{
    'currency_code': 'NGN',
    'available_balance': 50000,
    'held_balance': 20000,
    'pending_balance': 0,
    'lifetime_earned': 120000,
    'release_count': 3,
    'completed_contracts': 2,
    'total_withdrawn': 40000,
    'frozen_count': 0,
    'monthly': <dynamic>[],
  },
);

EarningsTransactionPageDto _pageDto() => EarningsTransactionPageDto.fromJson(
  <String, dynamic>{
    'items': <dynamic>[
      <String, dynamic>{
        'id': 'tx-1',
        'transaction_type': 'escrow_release',
        'currency_code': 'NGN',
        'amount': 10000,
        'direction': 'in',
        'created_at': '2026-10-01T12:00:00.000Z',
        'contract_id': 'contract-1',
      },
    ],
    'has_more': true,
    'next_cursor': <String, dynamic>{
      'created_at': '2026-10-01T12:00:00.000Z',
      'id': 'tx-1',
    },
  },
);

void main() {
  group('EarningsRepositoryImpl.getSummary', () {
    test('returns the server summary and caches the window', () async {
      final _FakeRemote remote = _FakeRemote(summary: _summaryDto());
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: remote,
        local: InMemoryEarningsLocalDataSource(),
      );

      final EarningsSummary summary = await repository.getSummary('NGN');

      expect(summary.lifetimeEarned, 120000);
      expect(remote.summaryCalls, 1);
      expect(await repository.getCachedSummary('NGN'), isNotNull);
    });

    test('rejects unsupported currencies before the RPC', () async {
      final _FakeRemote remote = _FakeRemote(summary: _summaryDto());
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: remote,
        local: InMemoryEarningsLocalDataSource(),
      );

      await expectLater(
        repository.getSummary('XX'),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.summaryCalls, 0);
    });

    test('falls back to the cached window when the network fails', () async {
      final InMemoryEarningsLocalDataSource local =
          InMemoryEarningsLocalDataSource();
      await local.saveSummary('NGN', _summaryDto());
      final _FakeRemote remote = _FakeRemote(
        error: const ApiException(
          kind: ApiExceptionKind.network,
          message: 'offline',
        ),
      );
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: remote,
        local: local,
      );

      final EarningsSummary summary = await repository.getSummary('NGN');

      expect(summary.lifetimeEarned, 120000);
    });

    test('rethrows when the network fails with no cached window', () async {
      final _FakeRemote remote = _FakeRemote(
        error: const ApiException(
          kind: ApiExceptionKind.network,
          message: 'offline',
        ),
      );
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: remote,
        local: InMemoryEarningsLocalDataSource(),
      );

      await expectLater(
        repository.getSummary('NGN'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('EarningsRepositoryImpl.listTransactions', () {
    test('returns the server page verbatim and caches it', () async {
      final _FakeRemote remote = _FakeRemote(page: _pageDto());
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: remote,
        local: InMemoryEarningsLocalDataSource(),
      );

      final EarningsTransactionPage page = await repository.listTransactions(
        currencyCode: 'NGN',
        type: EarningsHistoryFilter.earned,
      );

      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor?['id'], 'tx-1');
      expect(remote.lastFilters?['type'], EarningsHistoryFilter.earned);
    });

    test('rejects unknown filter types before the RPC', () async {
      final _FakeRemote remote = _FakeRemote(page: _pageDto());
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: remote,
        local: InMemoryEarningsLocalDataSource(),
      );

      await expectLater(
        repository.listTransactions(currencyCode: 'NGN', type: 'bogus'),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.historyCalls, 0);
    });

    test('builds stable cache keys per query and cursor', () {
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: _FakeRemote(),
        local: InMemoryEarningsLocalDataSource(),
      );

      final String first = repository.historyCacheKey(
        currencyCode: 'NGN',
        type: 'all',
        limit: 20,
      );
      final String second = repository.historyCacheKey(
        currencyCode: 'NGN',
        type: 'all',
        limit: 20,
      );
      final String cursorPage = repository.historyCacheKey(
        currencyCode: 'NGN',
        type: 'all',
        limit: 20,
        cursor: <String, dynamic>{
          'created_at': '2026-10-01T12:00:00.000Z',
          'id': 'tx-1',
        },
      );

      expect(first, second);
      expect(cursorPage == first, isFalse);
    });

    test('invalidateCache clears cached windows', () async {
      final InMemoryEarningsLocalDataSource local =
          InMemoryEarningsLocalDataSource();
      await local.saveSummary('NGN', _summaryDto());
      final EarningsRepository repository = EarningsRepositoryImpl(
        remote: _FakeRemote(summary: _summaryDto()),
        local: local,
      );

      await repository.invalidateCache();

      expect(await repository.getCachedSummary('NGN'), isNull);
    });
  });
}
