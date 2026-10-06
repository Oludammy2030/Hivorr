// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';

/// Load lifecycle of the service review provider (EP-03-12 §7.1).
enum ReviewLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing double-blind review state to the widget tree (EP-03-12).
///
/// Depends only on the [ServiceReviewService] abstraction and surfaces a
/// single [ApiException] on failure. Owns the viewer-scoped my-status memo
/// (`service_review_get_mine` per contract) plus the current listing page
/// (`service_review_get_for_listing`), keyset pagination
/// (`(revealed_at DESC, id DESC)` via opaque `uuid` cursor), and a
/// [WidgetsBindingObserver] lifecycle gate (no background refreshes —
/// [pausePolling]/[resumePolling]). Mirrors `ServiceContractProvider`
/// list/select/refresh shape.
///
/// This provider never decides reveal — it renders server `is_revealed`
/// verbatim (`AGENT.md` Rule 4).
class ServiceReviewProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ServiceReviewProvider({
    required ServiceReviewService service,
    HivorrLogger? logger,
  }) : _service = service,
       _logger = logger {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final ServiceReviewService _service;
  final HivorrLogger? _logger;

  final Map<String, MyReviewStatus> _myStatusByContract =
      <String, MyReviewStatus>{};
  List<ServiceReview> _listingReviews = const <ServiceReview>[];
  ReviewAggregate? _listingAggregate;
  String? _listingId;
  ReviewLoadState _loadState = ReviewLoadState.idle;
  ApiException? _error;
  bool _hasMore = false;
  String? _nextCursor;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Viewer-scoped status per contract id.
  Map<String, MyReviewStatus> get myStatusByContract =>
      Map<String, MyReviewStatus>.unmodifiable(_myStatusByContract);

  /// Status for [contractId], when loaded.
  MyReviewStatus? myStatusFor(String contractId) =>
      _myStatusByContract[contractId];

  /// Current listing page items, in server order (verbatim).
  List<ServiceReview> get listingReviews => _listingReviews;

  /// Aggregate header for the current listing page.
  ReviewAggregate? get listingAggregate => _listingAggregate;

  /// The listing id backing the current page.
  String? get listingId => _listingId;

  /// The load lifecycle state.
  ReviewLoadState get loadState => _loadState;

  /// Whether a load is in flight.
  bool get isLoading => _loadState == ReviewLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _loadState == ReviewLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// Whether the current listing page is empty (drives `HivorrEmptyState`).
  bool get isListingEmpty =>
      _loadState == ReviewLoadState.loaded && _listingReviews.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Whether another listing page exists.
  bool get hasMore => _hasMore;

  /// Opaque cursor for the next listing page.
  String? get nextCursor => _nextCursor;

  /// Loads the viewer's submission status for [contractId].
  ///
  /// Re-calling also lazy-triggers the server reveal on expiry
  /// (`service_review_get_mine` invokes `reveal_if_ready` before reading).
  Future<MyReviewStatus?> loadMyStatus(
    String contractId, {
    bool refresh = false,
  }) async {
    if (contractId.trim().isEmpty) return null;
    final String id = contractId.trim();
    if (isLoading && !refresh) return _myStatusByContract[id];
    _loadState = ReviewLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final MyReviewStatus status = await _service.getMyStatus(id);
      _myStatusByContract[id] = status;
      _loadState = ReviewLoadState.loaded;
      return status;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ReviewLoadState.error;
      _logger?.warning('Service review status load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      return null;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Submits a review and refreshes the memoized my-status for [contractId].
  Future<ServiceReview> submit({
    required String contractId,
    required int rating,
    String? comment,
  }) async {
    final ServiceReview created = await _service.submitReview(
      contractId: contractId,
      rating: rating,
      comment: comment,
    );
    try {
      final MyReviewStatus status = await _service.getMyStatus(
        contractId.trim(),
      );
      _myStatusByContract[contractId.trim()] = status;
    } on ApiException {
      _myStatusByContract[contractId.trim()] = MyReviewStatus(
        contractId: contractId.trim(),
        youHaveSubmitted: true,
        yourReview: created,
        revealedReviews: created.isRevealed
            ? <ServiceReview>[created]
            : const <ServiceReview>[],
        reviewCount: created.isRevealed ? 1 : 0,
      );
    }
    if (!_disposed) notifyListeners();
    return created;
  }

  /// Loads the first revealed page for [listingId].
  Future<void> loadForListing({
    required String listingId,
    required String professionalEntityId,
    required String professionId,
    int limit = 20,
  }) async {
    if (isLoading) return;
    _listingId = listingId.trim();
    _loadState = ReviewLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final ListingReviewsPage page = await _service.getForListing(
        listingId: _listingId!,
        professionalEntityId: professionalEntityId,
        professionId: professionId,
        limit: limit,
      );
      _listingReviews = page.reviews;
      _listingAggregate = page.aggregate;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = ReviewLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ReviewLoadState.error;
      _logger?.warning('Service listing reviews load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the next revealed page using [nextCursor] (no-op when exhausted).
  Future<void> loadMoreForListing({
    required String professionalEntityId,
    required String professionId,
  }) async {
    final String? listingId = _listingId;
    final String? cursor = _nextCursor;
    if (!_hasMore ||
        listingId == null ||
        cursor == null ||
        _loadState == ReviewLoadState.loading) {
      return;
    }
    _loadState = ReviewLoadState.loading;
    notifyListeners();
    try {
      final ListingReviewsPage page = await _service.getForListing(
        listingId: listingId,
        professionalEntityId: professionalEntityId,
        professionId: professionId,
        limit: 20,
        cursor: cursor,
      );
      _listingReviews = <ServiceReview>[..._listingReviews, ...page.reviews];
      if (page.aggregate != null) _listingAggregate = page.aggregate;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = ReviewLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ReviewLoadState.error;
      _logger?.warning(
        'Service listing reviews load-more failed',
        <String, Object?>{'kind': e.kind.name, 'code': e.code},
      );
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads my-status for [contractId] (pull-to-refresh / lifecycle resume).
  Future<void> refreshMyStatus(String contractId) async {
    final String id = contractId.trim();
    if (id.isEmpty || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final MyReviewStatus status = await _service.getMyStatus(id);
      _myStatusByContract[id] = status;
      _loadState = ReviewLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ReviewLoadState.error;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
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
