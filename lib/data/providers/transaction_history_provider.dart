// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';

/// Load lifecycle of the transaction history provider (EP-03-16).
enum TransactionHistoryLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed with nothing to show.
  error,
}

/// Provider exposing the paginated earnings ledger to the widget tree
/// (EP-03-16).
///
/// Depends only on the [ServiceEarningsService] abstraction and surfaces a
/// single [ApiException] on failure. Owns the item list in server order
/// (verbatim — never re-sorted), the keyset cursor (`hasMore`/`nextCursor`),
/// and the active filter set (type, contract, date window, currency).
/// Mirrors `ServiceContractProvider`
/// (`lib/data/providers/service_contract_provider.dart:38-312`) list shape.
/// Display-only: rows are server-projected; nothing here aggregates.
class TransactionHistoryProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  TransactionHistoryProvider({
    required ServiceEarningsService service,
    HivorrLogger? logger,
  }) : _service = service,
       _logger = logger;

  final ServiceEarningsService _service;
  final HivorrLogger? _logger;

  List<EarningsTransaction> _items = const <EarningsTransaction>[];
  TransactionHistoryLoadState _loadState = TransactionHistoryLoadState.idle;
  ApiException? _error;
  String _currency = 'NGN';
  String _type = EarningsHistoryFilter.all;
  String? _contractId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _hasMore = false;
  Map<String, dynamic>? _nextCursor;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _disposed = false;

  /// Rows for the current filter, in server order (verbatim).
  List<EarningsTransaction> get items => _items;

  /// The load lifecycle state.
  TransactionHistoryLoadState get loadState => _loadState;

  /// Whether a load is in flight.
  bool get isLoading => _loadState == TransactionHistoryLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _loadState == TransactionHistoryLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// Whether the next page is loading (infinite scroll).
  bool get isLoadingMore => _loadingMore;

  /// Whether the current page is empty (drives `HivorrEmptyState`).
  bool get isEmpty =>
      _loadState == TransactionHistoryLoadState.loaded && _items.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// The selected currency code.
  String get currency => _currency;

  /// The active history filter (see [EarningsHistoryFilter]).
  String get typeFilter => _type;

  /// The active contract scoping (`null` means all contracts).
  String? get contractId => _contractId;

  /// The active window start (`null` means unbounded).
  DateTime? get dateFrom => _dateFrom;

  /// The active window end (`null` means unbounded).
  DateTime? get dateTo => _dateTo;

  /// Whether another page exists.
  bool get hasMore => _hasMore;

  /// Opaque cursor for the next page.
  Map<String, dynamic>? get nextCursor => _nextCursor;

  /// Loads the first page for the current filter set.
  Future<void> load({bool refresh = false}) async {
    if (isLoading) return;
    if (refresh) {
      _hasMore = false;
      _nextCursor = null;
    }
    final bool hadData = _items.isNotEmpty;
    _loadState = TransactionHistoryLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final EarningsTransactionPage page = await _service.listHistory(
        currencyCode: _currency,
        type: _type,
        contractId: _contractId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      _items = page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = TransactionHistoryLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      if (!hadData) {
        _items = const <EarningsTransaction>[];
        _loadState = TransactionHistoryLoadState.error;
      } else {
        _loadState = TransactionHistoryLoadState.loaded;
      }
      _logger?.warning('Transaction history load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
        'currencyCode': _currency,
        'type': _type,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Appends the next page when [hasMore] is true (infinite scroll).
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;
    _loadingMore = true;
    _error = null;
    notifyListeners();
    try {
      final EarningsTransactionPage page = await _service.listHistory(
        currencyCode: _currency,
        type: _type,
        contractId: _contractId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        cursor: _nextCursor,
      );
      _items = <EarningsTransaction>[..._items, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning(
        'Transaction history pagination failed',
        <String, Object?>{'kind': e.kind.name, 'code': e.code},
      );
    } finally {
      _loadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-runs the first-page load (pull-to-refresh).
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    await load(refresh: true);
    _refreshing = false;
    if (!_disposed) notifyListeners();
  }

  /// Sets the history type filter and reloads from the first page.
  Future<void> setType(String type) async {
    if (type == _type) return;
    _type = type;
    _items = const <EarningsTransaction>[];
    await load(refresh: true);
  }

  /// Sets the currency and reloads from the first page.
  Future<void> setCurrency(String currency) async {
    if (currency == _currency) return;
    _currency = currency;
    _items = const <EarningsTransaction>[];
    await load(refresh: true);
  }

  /// Scopes the history to [contractId] (`null` clears) and reloads.
  Future<void> setContract(String? contractId) async {
    if (contractId == _contractId) return;
    _contractId = contractId;
    _items = const <EarningsTransaction>[];
    await load(refresh: true);
  }

  /// Sets the date window and reloads from the first page.
  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    _dateFrom = from;
    _dateTo = to;
    _items = const <EarningsTransaction>[];
    await load(refresh: true);
  }

  /// Clears type/contract/date filters to defaults and reloads.
  Future<void> clearFilters() async {
    _type = EarningsHistoryFilter.all;
    _contractId = null;
    _dateFrom = null;
    _dateTo = null;
    _items = const <EarningsTransaction>[];
    await load(refresh: true);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
