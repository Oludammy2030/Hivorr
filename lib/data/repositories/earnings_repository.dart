import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';

/// History filter vocabulary for earnings reads (EP-03-16).
///
/// Mirrors the RPC `p_filters.type` contract: `all`, `earned`, `withdrawn`,
/// `fund_locked`, `frozen`.
abstract final class EarningsHistoryFilter {
  const EarningsHistoryFilter._();

  /// Every ledger row touching the caller.
  static const String all = 'all';

  /// Inbound `escrow_release` rows (payee side).
  static const String earned = 'earned';

  /// `withdrawal` rows.
  static const String withdrawn = 'withdrawn';

  /// `escrow_fund` rows (held-fund visibility for the funder).
  static const String fundLocked = 'fund_locked';

  /// Rows whose backing escrow is `disputed`.
  static const String frozen = 'frozen';

  /// All selectable filters in display order.
  static const List<String> values = <String>[
    all,
    earned,
    withdrawn,
    fundLocked,
    frozen,
  ];

  /// Whether [type] is a known filter.
  static bool isSupported(String type) => values.contains(type);
}

/// Abstract contract for earnings data operations (EP-03-16).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6). Read-only: summaries
/// and pages are server-aggregated; this repository never writes ledger,
/// balance, escrow, or contract state.
abstract class EarningsRepository {
  /// Fetches the server-aggregated earnings summary for [currencyCode].
  ///
  /// Validates [currencyCode] against the supported set before the RPC call
  /// (fail-fast `PLT003`). Falls back to the cached window when the network
  /// read fails and a cached summary exists.
  Future<EarningsSummary> getSummary(String currencyCode);

  /// Returns the cached summary for [currencyCode], or `null` on miss/expiry.
  Future<EarningsSummary?> getCachedSummary(String currencyCode);

  /// Fetches one keyset-paginated history page.
  ///
  /// [type] must satisfy [EarningsHistoryFilter.isSupported] (fail-fast
  /// `PLT003`). [cursor] is the opaque RPC `{created_at, id}` keyset (`null`
  /// for the first page). Falls back to the cached page when the network
  /// read fails and a cached page exists.
  Future<EarningsTransactionPage> listTransactions({
    required String currencyCode,
    String type = EarningsHistoryFilter.all,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  });

  /// Returns the cached history page for [cacheKey], or `null` on miss.
  Future<EarningsTransactionPage?> getCachedPage(String cacheKey);

  /// Builds the stable cache key for a history query (page index excluded;
  /// cursor pages are cached per cursor).
  String historyCacheKey({
    required String currencyCode,
    required String type,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    required int limit,
    Map<String, dynamic>? cursor,
  });

  /// Clears all `finance:earnings:` windows (on release events / refresh).
  Future<void> invalidateCache();
}
