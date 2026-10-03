// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';

/// Load lifecycle of the service contract provider (EP-03-10 §8 D5).
enum ServiceContractLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing service contract state to the widget tree (EP-03-10).
///
/// Depends only on the [ContractService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized contract list + selection
/// (contract with milestones + events), keyset pagination
/// (`(created_at DESC, id DESC)` via opaque `uuid` cursor), an optional status
/// filter, and a [WidgetsBindingObserver] lifecycle gate (no background
/// refreshes — [pausePolling]/[resumePolling]). Mirrors `HireProvider` and
/// `ServiceListingProvider` list/select/refresh shape.
class ServiceContractProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ServiceContractProvider({
    required ContractService service,
    HivorrLogger? logger,
  }) : _service = service,
       _logger = logger {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final ContractService _service;
  final HivorrLogger? _logger;

  List<ServiceContract> _contracts = const <ServiceContract>[];
  ServiceContract? _selected;
  ServiceContractLoadState _loadState = ServiceContractLoadState.idle;
  ApiException? _error;
  String? _statusFilter;
  bool _hasMore = false;
  String? _nextCursor;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Contracts for the current filter, in server order (verbatim).
  List<ServiceContract> get contracts => _contracts;

  /// The selected contract (with milestones + events), or `null`.
  ServiceContract? get selected => _selected;

  /// The load lifecycle state.
  ServiceContractLoadState get loadState => _loadState;

  /// Whether a load is in flight.
  bool get isLoading => _loadState == ServiceContractLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _loadState == ServiceContractLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// Whether the current page is empty (drives `HivorrEmptyState`).
  bool get isEmpty =>
      _loadState == ServiceContractLoadState.loaded && _contracts.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// The active status filter (`null` means all).
  String? get statusFilter => _statusFilter;

  /// Whether another page exists.
  bool get hasMore => _hasMore;

  /// Opaque cursor for the next page.
  String? get nextCursor => _nextCursor;

  /// Loads the caller's contracts, optionally filtered by [status].
  Future<void> loadMine({String? status, bool refresh = false}) async {
    if (isLoading) return;
    if (!refresh) _statusFilter = status;
    _loadState = ServiceContractLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final ServiceContractPage page = await _service.listMine(
        status: _statusFilter,
        limit: 20,
      );
      _contracts = page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = ServiceContractLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceContractLoadState.error;
      _logger?.warning('Service contract load failed', <String, Object?>{
        'statusFilter': _statusFilter,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the next page using [nextCursor] (no-op when exhausted).
  Future<void> loadMore() async {
    if (!_hasMore ||
        _nextCursor == null ||
        _loadState == ServiceContractLoadState.loading) {
      return;
    }
    final String cursor = _nextCursor!;
    _loadState = ServiceContractLoadState.loading;
    notifyListeners();
    try {
      final ServiceContractPage page = await _service.listMine(
        status: _statusFilter,
        limit: 20,
        cursor: cursor,
      );
      _contracts = <ServiceContract>[..._contracts, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = ServiceContractLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceContractLoadState.error;
      _logger?.warning('Service contract load-more failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail (contract + milestones + events) for [contractId].
  Future<void> select(String contractId) async {
    if (isLoading) return;
    if (_selected?.id == contractId && isLoaded) return;
    _loadState = ServiceContractLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _selected = await _service.getContract(contractId);
      _loadState = ServiceContractLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceContractLoadState.error;
      _logger?.warning('Service contract detail load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final ServiceContract? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      _selected = await _service.getContract(current.id);
      _loadState = ServiceContractLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ServiceContractLoadState.error;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Sends an offer and prepends the authoritative contract.
  Future<ServiceContract> offer({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<ContractMilestoneInput> milestones,
    DateTime? offerExpiresAt,
  }) async {
    final ServiceContract created = await _service.offerContract(
      serviceListingId: serviceListingId,
      totalAmount: totalAmount,
      currencyCode: currencyCode,
      milestones: milestones,
      offerExpiresAt: offerExpiresAt,
    );
    _contracts = <ServiceContract>[created, ..._contracts];
    _selected = created;
    if (!_disposed) notifyListeners();
    return created;
  }

  /// Accepts the selected/known contract and syncs memoized state.
  Future<ServiceContract> accept(String contractId) async {
    final ServiceContract updated = await _service.acceptContract(contractId);
    _applyUpdated(updated);
    return updated;
  }

  /// Cancels the selected/known contract and syncs memoized state.
  Future<ServiceContract> cancel(String contractId, {String? reason}) async {
    final ServiceContract updated = await _service.cancelContract(
      contractId,
      reason: reason,
    );
    _applyUpdated(updated);
    return updated;
  }

  /// Marks a milestone complete and syncs the selected contract.
  Future<ServiceContract> completeMilestone({
    required String contractId,
    required String milestoneId,
    String? evidencePath,
  }) async {
    final ServiceContract updated = await _service.completeMilestone(
      contractId: contractId,
      milestoneId: milestoneId,
      evidencePath: evidencePath,
    );
    _applyUpdated(updated);
    return updated;
  }

  /// Verifies (or requests revision on) a milestone and syncs state.
  Future<ServiceContract> verifyMilestone({
    required String contractId,
    required String milestoneId,
    String action = 'verified',
  }) async {
    final ServiceContract updated = await _service.verifyMilestone(
      contractId: contractId,
      milestoneId: milestoneId,
      action: action,
    );
    _applyUpdated(updated);
    return updated;
  }

  /// Closes the selected/known contract and syncs memoized state.
  Future<ServiceContract> close(String contractId) async {
    final ServiceContract updated = await _service.closeContract(contractId);
    _applyUpdated(updated);
    return updated;
  }

  /// Applies an [updated] row to the memoized list + selection.
  void _applyUpdated(ServiceContract updated) {
    _contracts = _contracts
        .map((ServiceContract e) => e.id == updated.id ? updated : e)
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
