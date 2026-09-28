// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

/// Load lifecycle of the service listing provider (EP-03-08 §8 D5).
enum ServiceListingLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing owner service listing state to the widget tree
/// (EP-03-08).
///
/// Depends only on the [ServiceListingService] abstraction and surfaces a
/// single [ApiException] on failure. Owns the memoized owner list +
/// selection, keyset pagination (`(created_at DESC, id DESC)` via opaque
/// `uuid` cursor), an optional status filter, and a [WidgetsBindingObserver]
/// lifecycle gate (no background refreshes — [pausePolling]/[resumePolling]).
/// Mirrors `DisputeProvider` list/select/refresh shape.
class ServiceListingProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ServiceListingProvider({
    required ServiceListingService service,
    HivorrLogger? logger,
  })  : _service = service,
        _logger = logger {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final ServiceListingService _service;
  final HivorrLogger? _logger;

  List<MyServiceListing> _listings = const <MyServiceListing>[];
  MyServiceListing? _selected;
  ServiceListingLoadState _loadState = ServiceListingLoadState.idle;
  ApiException? _error;
  String? _statusFilter;
  bool _hasMore = false;
  String? _nextCursor;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Owner listings for the current filter, in server order (verbatim).
  List<MyServiceListing> get listings => _listings;

  /// The selected listing, or `null` before [select].
  MyServiceListing? get selected => _selected;

  /// The load lifecycle state.
  ServiceListingLoadState get loadState => _loadState;

  /// Whether a load is in flight.
  bool get isLoading => _loadState == ServiceListingLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _loadState == ServiceListingLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// Whether the current page is empty (drives `HivorrEmptyState`).
  bool get isEmpty => _loadState == ServiceListingLoadState.loaded && _listings.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// The active status filter (`null` means all).
  String? get statusFilter => _statusFilter;

  /// Whether another owner page exists.
  bool get hasMore => _hasMore;

  /// Opaque cursor for the next owner page.
  String? get nextCursor => _nextCursor;

  /// Loads the owner's listings, optionally filtered by [status].
  Future<void> loadMine({String? status, bool refresh = false}) async {
    if (isLoading) return;
    if (!refresh) _statusFilter = status;
    _loadState = ServiceListingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final MyListingPage page = await _service.listMine(
        status: _statusFilter,
        limit: 20,
      );
      _listings = page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = ServiceListingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceListingLoadState.error;
      _logger?.warning('Service listing load failed', <String, Object?>{
        'statusFilter': _statusFilter,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the next owner page using [nextCursor] (no-op when exhausted).
  Future<void> loadMore() async {
    if (!_hasMore ||
        _nextCursor == null ||
        _loadState == ServiceListingLoadState.loading) {
      return;
    }
    final String cursor = _nextCursor!;
    _loadState = ServiceListingLoadState.loading;
    notifyListeners();
    try {
      final MyListingPage page = await _service.listMine(
        status: _statusFilter,
        limit: 20,
        cursor: cursor,
      );
      _listings = <MyServiceListing>[..._listings, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = ServiceListingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceListingLoadState.error;
      _logger?.warning('Service listing load-more failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail (listing + ordered media) for [listingId] in one RPC.
  Future<void> select(String listingId) async {
    if (isLoading) return;
    if (_selected?.id == listingId && isLoaded) return;
    _loadState = ServiceListingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _selected = await _service.getListing(listingId);
      _loadState = ServiceListingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceListingLoadState.error;
      _logger?.warning('Service listing detail load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final MyServiceListing? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      _selected = await _service.getListing(current.id);
      _loadState = ServiceListingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceListingLoadState.error;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Creates a listing and prepends it to the memoized list.
  Future<MyServiceListing> create({
    required String professionId,
    required String title,
    required String description,
    required String pricingType,
    double? priceMin,
    double? priceMax,
    String currencyCode = 'NGN',
    String status = 'draft',
  }) async {
    final MyServiceListing created = await _service.createListing(
      professionId: professionId,
      title: title,
      description: description,
      pricingType: pricingType,
      priceMin: priceMin,
      priceMax: priceMax,
      currencyCode: currencyCode,
      status: status,
    );
    _listings = <MyServiceListing>[created, ..._listings];
    _selected = created;
    if (!_disposed) notifyListeners();
    return created;
  }

  /// Updates a listing and syncs the memoized list + selection.
  Future<MyServiceListing> update({
    required String listingId,
    String? title,
    String? description,
    String? professionId,
    String? pricingType,
    double? priceMin,
    double? priceMax,
    String? currencyCode,
  }) async {
    final MyServiceListing updated = await _service.updateListing(
      listingId: listingId,
      title: title,
      description: description,
      professionId: professionId,
      pricingType: pricingType,
      priceMin: priceMin,
      priceMax: priceMax,
      currencyCode: currencyCode,
    );
    _applyUpdated(updated);
    return updated;
  }

  /// Publishes a listing and syncs the memoized list + selection.
  Future<MyServiceListing> publish(String listingId) async {
    final MyServiceListing updated = await _service.publishListing(listingId);
    _applyUpdated(updated);
    return updated;
  }

  /// Unpublishes a listing and syncs the memoized list + selection.
  Future<MyServiceListing> unpublish(String listingId) async {
    final MyServiceListing updated = await _service.unpublishListing(listingId);
    _applyUpdated(updated);
    return updated;
  }

  /// Applies an [updated] row to the memoized list + selection.
  void _applyUpdated(MyServiceListing updated) {
    _listings = _listings
        .map((MyServiceListing e) => e.id == updated.id ? updated : e)
        .toList(growable: false);
    if (_selected?.id == updated.id) _selected = updated;
    if (!_disposed) notifyListeners();
  }

  /// Pauses background refreshes (lifecycle gate).
  void pausePolling() {
    _paused = true;
  }

  /// Resumes background refreshes (lifecycle gate).
  void resumePolling() {
    _paused = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // Observer was never attached (no live binding).
    }
    super.dispose();
  }
}
