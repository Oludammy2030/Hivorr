// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/systems/finance/services/service_earnings_service.dart';

/// Notification channel used for earnings events (EP-03-16).
///
/// Reuses the escrow system channel — earnings notifications are release
/// follow-ups, not a new fan-out (EP-03-18 owns lifecycle fan-out).
abstract final class EarningsNotificationChannel {
  const EarningsNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the earnings provider (EP-03-16).
enum EarningsLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed with no cached summary to show.
  error,
}

/// Provider exposing server-verified earnings summaries (EP-03-16).
///
/// Depends only on the [ServiceEarningsService] abstraction and surfaces a
/// single [ApiException] on failure. Owns the per-currency summary map, the
/// selected currency, a lifecycle-aware load pattern, optional polling (only
/// while visible — started/stopped by the screens), and a one-shot
/// `earnings_released` [HivorrNotification] consumed from the EP-03-11
/// release flow (mirrors `FinancialProvider`
/// `lib/data/providers/financial_provider.dart:49-282`). Display-only: every
/// figure is server-aggregated; nothing here computes settlement.
class EarningsProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the `earnings_released` hook; [logger]
  /// enables PII-safe structured logging. [pollInterval] defaults to 15s
  /// (mirrors `FinancialProvider`); [clock] is injectable for tests.
  EarningsProvider({
    required ServiceEarningsService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    Duration? pollInterval,
    DateTime Function()? clock,
  }) : _service = service,
       _logger = logger,
       _notificationProvider = notificationProvider,
       _pollInterval = pollInterval ?? const Duration(seconds: 15),
       _clock = clock ?? DateTime.now;

  final ServiceEarningsService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  final Map<String, EarningsSummary> _summaries = <String, EarningsSummary>{};
  String _currency = 'NGN';
  EarningsLoadState _loadState = EarningsLoadState.idle;
  bool _refreshing = false;
  ApiException? _error;

  Timer? _pollTimer;
  bool _paused = false;
  bool _pollingEnabled = false;
  bool _disposed = false;

  /// Per-currency summaries keyed by currency code.
  Map<String, EarningsSummary> get summaries => _summaries;

  /// The summary for the selected currency, or `null` before the first load.
  EarningsSummary? get summary => _summaries[_currency];

  /// The selected currency code.
  String get currency => _currency;

  /// The load lifecycle state.
  EarningsLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == EarningsLoadState.loading;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// The error from the last failed operation (`null` on success).
  ///
  /// A failed refresh keeps the previous summary visible (offline window);
  /// only a failure with nothing to show moves [loadState] to `error`.
  ApiException? get lastError => _error;

  /// Whether a summary has been loaded at least once.
  bool get isLoaded => _loadState == EarningsLoadState.loaded;

  /// Selects [currency] and loads its summary when absent.
  Future<void> setCurrency(String currency) async {
    if (currency == _currency) return;
    _currency = currency;
    if (!_summaries.containsKey(currency)) {
      await load();
    } else if (!_disposed) {
      notifyListeners();
    }
  }

  /// Loads the summary for the selected currency.
  Future<void> load() async {
    if (isLoading) return;
    final bool hadData = _summaries.containsKey(_currency);
    _loadState = EarningsLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final EarningsSummary s = await _service.getSummary(_currency);
      _summaries[_currency] = s;
      _loadState = EarningsLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      if (!hadData && !_summaries.containsKey(_currency)) {
        _loadState = EarningsLoadState.error;
      } else {
        _loadState = EarningsLoadState.loaded;
      }
      _logger?.warning('Earnings summary load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
        'currencyCode': _currency,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the summary for the selected currency (pull-to-refresh).
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final EarningsSummary s = await _service.getSummary(_currency);
      _summaries[_currency] = s;
      _loadState = EarningsLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      if (!_summaries.containsKey(_currency)) {
        _loadState = EarningsLoadState.error;
      }
      _logger?.warning('Earnings summary refresh failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
        'currencyCode': _currency,
      });
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads summaries for every supported currency, sequentially.
  ///
  /// The selected currency loads first (default-currency-first convention
  /// per `BalanceOverviewCard`); remaining currencies follow in vocabulary
  /// order. Failures are recorded per currency without aborting the rest.
  Future<void> loadAll() async {
    final List<String> ordered = <String>[
      _currency,
      for (final String code in ServiceEarningsService.supportedCodes)
        if (code != _currency) code,
    ];
    for (final String code in ordered) {
      try {
        final EarningsSummary s = await _service.getSummary(code);
        _summaries[code] = s;
      } on ApiException catch (e) {
        _error = e;
        _logger?.warning('Earnings summary load failed', <String, Object?>{
          'kind': e.kind.name,
          'code': e.code,
          'currencyCode': code,
        });
      }
    }
    _loadState = _summaries.isEmpty
        ? EarningsLoadState.error
        : EarningsLoadState.loaded;
    if (!_disposed) notifyListeners();
  }

  /// Handles a verified release: invalidates the cached windows, refreshes
  /// the selected currency, and emits a one-shot `Payment received`
  /// notification deep-linking `/dashboard/earnings`.
  ///
  /// Consumed from the EP-03-11 release flow (`notifyContractMilestoneEvent`
  /// `milestone_released`); carries no amounts or PII in the body.
  Future<void> notifyEarningsReleased({
    required String contractId,
    required String milestoneId,
  }) async {
    await _service.invalidateCache();
    await refresh();
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null || _paused) return;
    final int id =
        'earnings:$contractId:$milestoneId:released'.hashCode & 0x7fffffff;
    await notifications.showLocal(
      HivorrNotification(
        id: id,
        title: 'Payment received',
        body: 'A milestone payment is now available — tap to view earnings.',
        channelId: EarningsNotificationChannel.system,
        priority: NotificationPriority.high,
        timestamp: _clock(),
        actionRoute: '/dashboard/earnings',
        payload: <String, dynamic>{
          'contractId': contractId,
          'milestoneId': milestoneId,
          'eventType': 'earnings_released',
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Polling lifecycle (mirrors FinancialProvider): poll only while a summary
  // is loaded and the earnings screens are visible.
  // ---------------------------------------------------------------------------

  /// Enables polling (refresh loop) while a summary is loaded.
  void startPolling() {
    _pollingEnabled = true;
    if (isLoaded) _ensurePollTimer();
  }

  /// Disables polling and cancels any pending timer.
  void stopPolling() {
    _pollingEnabled = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Pauses polling without disabling it (app background).
  void pausePolling() {
    if (!_pollingEnabled || _paused) return;
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes polling after a pause.
  void resumePolling() {
    if (!_paused) return;
    _paused = false;
    if (_pollingEnabled && isLoaded) _ensurePollTimer();
  }

  void _ensurePollTimer() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_onPollTick()));
  }

  Future<void> _onPollTick() async {
    if (!isLoaded || _paused) {
      stopPolling();
      return;
    }
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
