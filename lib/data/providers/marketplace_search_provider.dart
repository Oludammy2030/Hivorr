import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/repositories/service_search_repository.dart';

/// Lifecycle states for [MarketplaceSearchProvider].
enum MarketplaceSearchState { idle, loading, loaded, error }

/// Provider exposing ranked marketplace search state to the widget tree.
///
/// Depends only on [ServiceSearchRepository] and surfaces a single
/// [ApiException] on failure. Mirrors `TaxonomyProvider` (`lib/data/providers/taxonomy_provider.dart:31`)
/// debounce and lifecycle (`idle/loading/loaded/error`), but **never reorders**
/// the RPC `items` (AGENT.md:7 Deterministic Core — `items` assigned verbatim).
class MarketplaceSearchProvider extends ChangeNotifier {
  MarketplaceSearchProvider({required this.repository});

  /// The repository backing ranked search (server-decided order).
  final ServiceSearchRepository repository;

  /// Debounce window for query propagation (mirrors `TaxonomyProvider` 250ms).
  static const Duration searchDebounce = Duration(milliseconds: 250);

  MarketplaceSearchState _state = MarketplaceSearchState.idle;
  List<ServiceListing> _items = const <ServiceListing>[];
  bool _hasMore = false;
  ServiceListingCursor? _nextCursor;
  DateTime? _weightsVersion;
  ServiceSearchFilters _filters = const ServiceSearchFilters();
  String _query = '';
  String? _professionId;
  ApiException? _error;
  Timer? _debounce;

  // ── getters ────────────────────────────────────────────────────────────

  MarketplaceSearchState get state => _state;
  List<ServiceListing> get items => _items;
  bool get hasMore => _hasMore;
  ServiceListingCursor? get nextCursor => _nextCursor;
  DateTime? get weightsVersion => _weightsVersion;
  ServiceSearchFilters get filters => _filters;
  String get query => _query;
  String? get professionId => _professionId;
  ApiException? get error => _error;

  /// Whether the current page is empty (drives `HivorrEmptyState`).
  bool get isEmpty => _state == MarketplaceSearchState.loaded && _items.isEmpty;

  /// Whether a load is in flight.
  bool get isLoading => _state == MarketplaceSearchState.loading;

  // ── public API ─────────────────────────────────────────────────────────

  /// Sets the profession filter (`p_profession_id`).
  void setProfessionId(String? id) {
    _professionId = id;
    notifyListeners();
  }

  /// Sets the `p_filters` value object (price/rating/verified).
  void setFilters(ServiceSearchFilters filters) {
    _filters = filters;
    notifyListeners();
  }

  /// Sets the FTS query, debounced (mirrors TaxonomyProvider).
  void setQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      _query = query;
      notifyListeners();
    });
  }

  /// Clears the query immediately (no debounce).
  void clearQuery() {
    _debounce?.cancel();
    _debounce = null;
    _query = '';
    notifyListeners();
  }

  /// Executes the ranked search for the current filters/query/profession.
  ///
  /// `items` are assigned **verbatim** from the RPC `data.items` (no sort).
  /// Callers must not client-sort the returned list (CI lint checks
  /// `sort.*score`).
  Future<void> search({int limit = 20}) => _run(() async {
    final ServiceSearchPage page = await repository.search(
      professionId: _professionId,
      query: _query.trim().isEmpty ? null : _query.trim(),
      filters: _filters.isEmpty ? null : _filters,
      cursor: null,
      limit: limit,
    );
    _items = page.items;
    _hasMore = page.hasMore;
    _nextCursor = page.nextCursor;
    _weightsVersion = page.weightsVersion;
  });

  /// Loads the next page using `nextCursor` (keyset `score,id`).
  Future<void> loadMore({int limit = 20}) async {
    if (!_hasMore ||
        _nextCursor == null ||
        _state == MarketplaceSearchState.loading) {
      return;
    }
    await _run(() async {
      final ServiceSearchPage page = await repository.search(
        professionId: _professionId,
        query: _query.trim().isEmpty ? null : _query.trim(),
        filters: _filters.isEmpty ? null : _filters,
        cursor: _nextCursor,
        limit: limit,
      );
      _items = <ServiceListing>[..._items, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _weightsVersion = page.weightsVersion ?? _weightsVersion;
    }, isLoadMore: true);
  }

  /// Clears cached pages and resets state (e.g., on `weights_version` bump).
  Future<void> invalidate() async {
    await repository.invalidate();
    _items = const <ServiceListing>[];
    _hasMore = false;
    _nextCursor = null;
    _error = null;
    _state = MarketplaceSearchState.idle;
    notifyListeners();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool isLoadMore = false,
  }) async {
    if (!isLoadMore) {
      _state = MarketplaceSearchState.loading;
      _error = null;
      notifyListeners();
    } else {
      _state = MarketplaceSearchState.loading;
      notifyListeners();
    }
    try {
      await action();
      _state = MarketplaceSearchState.loaded;
    } on ApiException catch (e) {
      _error = e;
      if (!isLoadMore) {
        _items = const <ServiceListing>[];
        _hasMore = false;
        _nextCursor = null;
      }
      _state = MarketplaceSearchState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
