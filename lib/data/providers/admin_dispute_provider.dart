// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/entities/service_dispute_contract_summary.dart';
import 'package:hivorr/data/repositories/admin_dispute_repository.dart';

/// Load lifecycle of the admin dispute queue (mirrors [DisputeLoadState]).
enum AdminDisputeLoadState { idle, loading, loaded, error }

/// Provider exposing the admin dispute queue to the Admin shell (R3).
///
/// Read-only: queue paging + single-case reads through
/// [AdminDisputeRepository]. Screen-level access is gated by `AdminGate`
/// over the existing `AdminReviewProvider`; row-level authorization is
/// server-side via `is_platform_admin()`. Manual refresh + foreground resume
/// only — no background polling.
class AdminDisputeProvider extends ChangeNotifier with WidgetsBindingObserver {
  AdminDisputeProvider({required AdminDisputeRepository repository, HivorrLogger? logger})
    : _repository = repository,
      _logger = logger {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle resume gate will not be attached.
    }
  }

  final AdminDisputeRepository _repository;
  final HivorrLogger? _logger;

  List<DisputeCase> _queue = const <DisputeCase>[];
  int _totalCount = 0;
  String? _statusFilter;
  DisputeCase? _selected;
  List<DisputeEvidence> _evidence = const <DisputeEvidence>[];
  DisputeResolution? _resolution;
  ServiceDisputeContractSummary? _contractSummary;
  AdminDisputeLoadState _loadState = AdminDisputeLoadState.idle;
  ApiException? _error;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  static const int pageSize = 50;

  /// Current queue page rows.
  List<DisputeCase> get queue => _queue;

  /// Server total for the current filter (drives "Load more").
  int get totalCount => _totalCount;

  /// Active status filter, `null` for all.
  String? get statusFilter => _statusFilter;

  /// Whether more pages remain server-side.
  bool get hasMore => _queue.length < _totalCount;

  /// The selected case, or `null` before [select].
  DisputeCase? get selected => _selected;

  /// Evidence of the selected case.
  List<DisputeEvidence> get evidence => _evidence;

  /// Resolution of the selected case, when resolved.
  DisputeResolution? get resolution => _resolution;

  /// Joined engagement summary of the selected case, when contract-anchored.
  ServiceDisputeContractSummary? get contractSummary => _contractSummary;

  AdminDisputeLoadState get loadState => _loadState;
  bool get isLoading => _loadState == AdminDisputeLoadState.loading;
  bool get isLoaded => _loadState == AdminDisputeLoadState.loaded;
  bool get isRefreshing => _refreshing;
  ApiException? get lastError => _error;

  /// Loads the first page for [status] (`null` for all).
  Future<void> loadQueue({String? status}) async {
    if (isLoading) return;
    _statusFilter = status;
    _loadState = AdminDisputeLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final page = await _repository.listDisputes(
        status: status,
        limit: pageSize,
      );
      _queue = page.items;
      _totalCount = page.totalCount;
      _loadState = AdminDisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = AdminDisputeLoadState.error;
      _logger?.warning('Admin dispute queue load failed', <String, Object?>{
        'statusFilter': status,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Appends the next page when [hasMore].
  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    _loadState = AdminDisputeLoadState.loading;
    notifyListeners();
    try {
      final page = await _repository.listDisputes(
        status: _statusFilter,
        limit: pageSize,
        offset: _queue.length,
      );
      _queue = <DisputeCase>[..._queue, ...page.items];
      _totalCount = page.totalCount;
      _loadState = AdminDisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = AdminDisputeLoadState.error;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads one case with evidence, resolution, and contract join.
  Future<void> select(String caseId) async {
    if (isLoading) return;
    if (_selected?.id == caseId && isLoaded) return;
    _loadState = AdminDisputeLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final detail = await _repository.getCase(caseId);
      _selected = detail.disputeCase;
      _evidence = detail.evidence;
      _resolution = detail.resolution;
      _contractSummary = detail.contractSummary;
      _loadState = AdminDisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = AdminDisputeLoadState.error;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current queue page (pull-to-refresh / resume).
  Future<void> refresh() async {
    if (_refreshing || _paused) return;
    _refreshing = true;
    notifyListeners();
    try {
      final page = await _repository.listDisputes(
        status: _statusFilter,
        limit: _queue.isEmpty ? pageSize : _queue.length,
      );
      _queue = page.items;
      _totalCount = page.totalCount;
      _loadState = AdminDisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void pausePolling() => _paused = true;
  void resumePolling() => _paused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) unawaited(refresh());
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
