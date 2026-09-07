// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';
import 'package:hivorr/systems/finance/services/financial_deposit_service.dart';

/// Load lifecycle of the deposit provider (EP-02-16).
enum DepositLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing deposit-read state to the widget tree (EP-02-16).
///
/// Read-only (deposit recording/name-verification is service-role work). Owns
/// the RLS-scoped deposit list plus name-match aggregates consumed by the
/// [DepositDetailsPanel] and history badge.
class FinancialDepositProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  ///
  /// [logger] enables PII-safe structured logging.
  FinancialDepositProvider({
    required FinancialDepositService service,
    HivorrLogger? logger,
  })  : _service = service,
        _logger = logger;

  final FinancialDepositService _service;
  final HivorrLogger? _logger;

  List<Deposit> _deposits = const <Deposit>[];
  DepositLoadState _loadState = DepositLoadState.idle;
  ApiException? _error;
  bool _disposed = false;

  /// The authenticated entity's deposits, newest first.
  List<Deposit> get deposits => _deposits;

  /// The load lifecycle state.
  DepositLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == DepositLoadState.loading;

  /// Whether the provider has completed at least one successful load.
  ///
  /// Deliberately excludes [DepositLoadState.error] so views can distinguish an
  /// initial-load failure (show a retry error state) from a refresh failure
  /// after a successful load (keep showing the deposits).
  bool get isLoaded => _loadState == DepositLoadState.loaded;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Number of deposits whose payer name matched the profile legal name.
  int get matchedCount => _countFor(DepositNameMatchStatus.matched);

  /// Number of deposits whose payer name mismatched.
  int get mismatchedCount => _countFor(DepositNameMatchStatus.mismatched);

  /// Number of deposits awaiting server-side name verification.
  int get pendingCount => _countFor(DepositNameMatchStatus.pending);

  /// Number of deposits with no payer name recorded yet.
  int get unverifiedCount => _countFor(DepositNameMatchStatus.unverified);

  /// Loads the deposit list.
  Future<void> load() async {
    if (isLoading) return;
    _loadState = DepositLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _deposits = await _service.listDeposits();
      _loadState = DepositLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = DepositLoadState.error;
      _logger?.warning('Deposit provider load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  int _countFor(DepositNameMatchStatus status) =>
      _deposits.where((Deposit d) => d.nameMatchStatus == status).length;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}