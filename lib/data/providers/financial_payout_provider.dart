// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';

/// Load lifecycle of the payout provider (EP-02-16).
enum PayoutLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing bound payout-account state to the widget tree (EP-02-16).
///
/// Depends only on the [FinancialPayoutService] abstraction and surfaces a
/// single [ApiException] on failure. Owns the display mirror of bound grant
/// accounts (bind is server-authoritative via RPC; the list mirror is filled
/// by each successful bind) plus write-lifecycle flags for bind/withdraw.
class FinancialPayoutProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  ///
  /// [logger] enables PII-safe structured logging.
  FinancialPayoutProvider({
    required FinancialPayoutService service,
    HivorrLogger? logger,
  })  : _service = service,
        _logger = logger;

  final FinancialPayoutService _service;
  final HivorrLogger? _logger;

  List<PayoutAccount> _accounts = const <PayoutAccount>[];
  PayoutLoadState _loadState = PayoutLoadState.idle;
  bool _binding = false;
  bool _withdrawing = false;
  ApiException? _error;
  String? _successMessage;
  bool _disposed = false;

  /// The display mirror of bound payout accounts.
  List<PayoutAccount> get accounts => _accounts;

  /// The load lifecycle state.
  PayoutLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == PayoutLoadState.loading;

  /// Whether the provider has completed at least one successful load.
  ///
  /// Deliberately excludes [PayoutLoadState.error] so views can distinguish an
  /// initial-load failure (show a retry error state) from a refresh failure
  /// after a successful load (keep showing the mirror).
  bool get isLoaded => _loadState == PayoutLoadState.loaded;

  /// Whether a bind is in flight.
  bool get isBinding => _binding;

  /// Whether a withdrawal is in flight.
  bool get isWithdrawing => _withdrawing;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// User-facing success note from the last completed bind/withdraw
  /// (cleared by the next operation).
  String? get successMessage => _successMessage;

  /// Loads the bound-account mirror.
  Future<void> load() async {
    if (isLoading) return;
    _loadState = PayoutLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _accounts = await _service.listPayoutAccounts();
      _loadState = PayoutLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = PayoutLoadState.error;
      _logger?.warning('Payout provider load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the bound-account mirror (post-bind refresh).
  Future<void> refresh() => load();

  /// Binds a payout account.
  ///
  /// On success the returned account is appended to the mirror (deduplicated
  /// by id) and [successMessage] is set; on failure [lastError] holds the
  /// typed [ApiException].
  Future<PayoutAccount?> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    if (_binding) return null;
    _binding = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      final PayoutAccount account = await _service.bindAccount(
        currencyCode: currencyCode,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      );
      if (_accounts.any((PayoutAccount a) => a.id == account.id)) {
        _accounts = List<PayoutAccount>.of(_accounts);
      } else {
        _accounts = <PayoutAccount>[account, ..._accounts];
      }
      _successMessage =
          'Payout account bound. Ownership verification is pending.';
      return account;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Payout bind failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      return null;
    } finally {
      _binding = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Withdraws to a verified payout account.
  ///
  /// On success [successMessage] is set and the server's
  /// [WithdrawalResult] is returned (the caller refreshes balances through
  /// [FinancialProvider]); on failure [lastError] holds the typed
  /// [ApiException].
  Future<WithdrawalResult?> withdraw({
    required String payoutAccountId,
    required double amount,
  }) async {
    if (_withdrawing) return null;
    _withdrawing = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      final WithdrawalResult result = await _service.withdraw(
        payoutAccountId: payoutAccountId,
        amount: amount,
      );
      _successMessage = 'Withdrawal initiated.';
      return result;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Withdrawal failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      return null;
    } finally {
      _withdrawing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Consumes the transient success note (returns and clears it).
  String? takeSuccessMessage() {
    final String? message = _successMessage;
    _successMessage = null;
    return message;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}