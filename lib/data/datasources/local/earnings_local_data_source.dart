import 'package:hivorr/core/cache/cache_manager.dart';
import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';

/// Cache key prefix for earnings windows (EP-03-16).
const String earningsCachePrefix = 'finance:earnings:';

/// Summary window TTL: 60 seconds per TIP §7.4 (release events invalidate).
const Duration earningsSummaryCacheTtl = Duration(seconds: 60);

/// History window TTL: 60 seconds per TIP §7.4.
const Duration earningsHistoryCacheTtl = Duration(seconds: 60);

/// Abstract contract for the local (cache) side of earnings reads (EP-03-16).
///
/// Defines the transient window the repository consults for offline display
/// and release-event coherence, mirroring `ServiceSearchLocalDataSource`
/// (`lib/data/datasources/local/service_search_local_data_source.dart:9`).
/// Process-lifetime only — never persisted, no PII at rest.
abstract class EarningsLocalDataSource {
  /// Returns the cached summary for [currencyCode], or `null` on miss/expiry.
  Future<EarningsSummaryDto?> getSummary(String currencyCode);

  /// Caches [summary] under `[earningsCachePrefix]summary:[currencyCode]`.
  Future<void> saveSummary(String currencyCode, EarningsSummaryDto summary);

  /// Returns the cached history page for [key], or `null` on miss/expiry.
  Future<EarningsTransactionPageDto?> getPage(String key);

  /// Caches [page] under `[earningsCachePrefix]history:[key]`.
  Future<void> savePage(String key, EarningsTransactionPageDto page);

  /// Clears all `finance:earnings:` entries (on release events / refresh).
  Future<void> invalidate();
}

/// [CacheManager]-backed implementation of [EarningsLocalDataSource].
class CacheManagerEarningsLocalDataSource implements EarningsLocalDataSource {
  CacheManagerEarningsLocalDataSource({this.cache});

  /// The cache manager backing reads/writes, or `null` to use the shared
  /// singleton (falls back to in-memory when uninitialized).
  final CacheManager? cache;

  final Map<String, EarningsSummaryDto> _summaryFallback =
      <String, EarningsSummaryDto>{};
  final Map<String, EarningsTransactionPageDto> _pageFallback =
      <String, EarningsTransactionPageDto>{};

  CacheManager? get _resolved =>
      cache ?? (CacheManager.isInitialized ? CacheManager.instance : null);

  String _summaryKey(String currencyCode) =>
      '${earningsCachePrefix}summary:$currencyCode';

  String _pageKey(String key) => '${earningsCachePrefix}history:$key';

  @override
  Future<EarningsSummaryDto?> getSummary(String currencyCode) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      return c.get<EarningsSummaryDto>(_summaryKey(currencyCode));
    }
    return _summaryFallback[_summaryKey(currencyCode)];
  }

  @override
  Future<void> saveSummary(
    String currencyCode,
    EarningsSummaryDto summary,
  ) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      c.put<EarningsSummaryDto>(
        _summaryKey(currencyCode),
        summary,
        ttl: earningsSummaryCacheTtl,
      );
    } else {
      _summaryFallback[_summaryKey(currencyCode)] = summary;
    }
  }

  @override
  Future<EarningsTransactionPageDto?> getPage(String key) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      return c.get<EarningsTransactionPageDto>(_pageKey(key));
    }
    return _pageFallback[_pageKey(key)];
  }

  @override
  Future<void> savePage(String key, EarningsTransactionPageDto page) async {
    final CacheManager? c = _resolved;
    if (c != null) {
      c.put<EarningsTransactionPageDto>(
        _pageKey(key),
        page,
        ttl: earningsHistoryCacheTtl,
      );
    } else {
      _pageFallback[_pageKey(key)] = page;
    }
  }

  @override
  Future<void> invalidate() async {
    final CacheManager? c = _resolved;
    if (c != null) {
      c.invalidatePrefix(earningsCachePrefix);
    }
    _summaryFallback.clear();
    _pageFallback.clear();
  }
}

/// In-memory implementation for tests / dependency-free wiring.
class InMemoryEarningsLocalDataSource implements EarningsLocalDataSource {
  InMemoryEarningsLocalDataSource();

  final Map<String, EarningsSummaryDto> _summaries =
      <String, EarningsSummaryDto>{};
  final Map<String, EarningsTransactionPageDto> _pages =
      <String, EarningsTransactionPageDto>{};

  @override
  Future<EarningsSummaryDto?> getSummary(String currencyCode) async =>
      _summaries['${earningsCachePrefix}summary:$currencyCode'];

  @override
  Future<void> saveSummary(
    String currencyCode,
    EarningsSummaryDto summary,
  ) async {
    _summaries['${earningsCachePrefix}summary:$currencyCode'] = summary;
  }

  @override
  Future<EarningsTransactionPageDto?> getPage(String key) async =>
      _pages['${earningsCachePrefix}history:$key'];

  @override
  Future<void> savePage(String key, EarningsTransactionPageDto page) async {
    _pages['${earningsCachePrefix}history:$key'] = page;
  }

  @override
  Future<void> invalidate() async {
    _summaries.clear();
    _pages.clear();
  }
}
