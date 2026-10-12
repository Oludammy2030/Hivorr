// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/systems/business/services/business_service.dart';

/// Load lifecycle of the business provider (identity audit Phase 2a).
enum BusinessLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing business identity state to the widget tree.
///
/// Depends only on the [BusinessService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized per-entity business list;
/// verification decisions stay server-side (admin review RPCs).
class BusinessProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  BusinessProvider({required BusinessService service, HivorrLogger? logger})
    : _service = service,
      _logger = logger;

  final BusinessService _service;
  final HivorrLogger? _logger;

  List<Business> _businesses = const <Business>[];
  BusinessLoadState _loadState = BusinessLoadState.idle;
  ApiException? _error;
  bool _disposed = false;

  /// The caller's businesses in server order (verbatim).
  List<Business> get businesses => _businesses;

  /// The load lifecycle state.
  BusinessLoadState get loadState => _loadState;

  /// Whether a load is in flight.
  bool get isLoading => _loadState == BusinessLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _loadState == BusinessLoadState.loaded;

  /// Whether the current list is empty.
  bool get isEmpty =>
      _loadState == BusinessLoadState.loaded && _businesses.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Loads the businesses for [entityId].
  Future<void> loadMine({required String entityId}) async {
    if (isLoading) return;
    _loadState = BusinessLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _businesses = await _service.listMine(entityId: entityId);
      _loadState = BusinessLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = BusinessLoadState.error;
      _logger?.warning('Business list load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Creates a business and appends the authoritative row.
  Future<Business> create({
    required String entityId,
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  }) async {
    final Business created = await _service.createBusiness(
      tradingName: tradingName,
      registeredLegalName: registeredLegalName,
      cacNumber: cacNumber,
    );
    await _service.joinBusiness(businessId: created.id, entityId: entityId);
    await loadMine(entityId: entityId);
    return created;
  }

  /// Deletes the caller's membership and refreshes the list.
  Future<void> leave({required String businessId, required String entityId}) async {
    await _service.leaveBusiness(businessId: businessId, entityId: entityId);
    await loadMine(entityId: entityId);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
