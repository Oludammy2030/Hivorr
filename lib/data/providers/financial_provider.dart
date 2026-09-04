// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

/// Notification channel used for financial-profile events (EP-02-13 §5.6).
abstract final class FinanceNotificationChannel {
  const FinanceNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the financial provider (EP-02-13 §5.5).
enum FinancialLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded (profile may still be null pre-creation).
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing financial profile state to the widget tree (EP-02-13).
///
/// Depends only on the [FinancialService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the profile + status snapshot, a
/// lifecycle-aware load pattern, optional polling (only while a non-terminal
/// profile exists), and a one-shot `profile_created` [HivorrNotification]
/// (mirrors `VerificationProvider`
/// `lib/data/providers/verification_provider.dart:42-308`).
class FinancialProvider extends ChangeNotifier {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the `profile_created` notification hook;
  /// [logger] enables PII-safe structured logging. [pollInterval] defaults to
  /// 15s; [clock] is injectable for deterministic tests.
  FinancialProvider({
    required FinancialService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    Duration? pollInterval,
    DateTime Function()? clock,
  })  : _service = service,
        _logger = logger,
        _notificationProvider = notificationProvider,
        _pollInterval = pollInterval ?? const Duration(seconds: 15),
        _clock = clock ?? DateTime.now;

  final FinancialService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  FinancialProfile? _profile;
  final List<CurrencyAccount> _accounts = const <CurrencyAccount>[];
  Map<String, Balance> _balances = <String, Balance>{};
  FinancialStatus? _status;
  FinancialLoadState _loadState = FinancialLoadState.idle;
  bool _creating = false;
  bool _refreshing = false;
  ApiException? _error;

  Timer? _pollTimer;
  bool _paused = false;
  bool _pollingEnabled = false;
  bool _disposed = false;

  /// The latest financial profile, or `null` before the first fetch
  /// (pre-creation state).
  FinancialProfile? get profile => _profile;

  /// The currency accounts attached to the profile.
  List<CurrencyAccount> get accounts => _accounts;

  /// Per-currency balance map keyed by currency code.
  Map<String, Balance> get balances => _balances;

  /// The latest aggregated financial status.
  FinancialStatus? get status => _status;

  /// The load lifecycle state.
  FinancialLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == FinancialLoadState.loading;

  /// Whether a profile creation is in flight.
  bool get isCreating => _creating;

  /// Whether a status refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Whether the provider has been loaded at least once.
  bool get isLoaded => _profile != null || _status != null;

  /// Loads profile + status. When the profile is null (no profile yet), only
  /// `getProfile` is called to avoid a `financial_status_get` failure.
  Future<void> load() async {
    if (isLoading) return;
    _loadState = FinancialLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final FinancialProfile? p = await _service.getProfile();
      _profile = p;
      if (p != null) {
        final FinancialStatus s = await _service.getStatus();
        _applyStatus(s);
      }
      _loadState = FinancialLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = FinancialLoadState.error;
      _logger?.warning('Financial provider load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the aggregated status and balances.
  Future<void> refreshStatus() async {
    if (_refreshing) return;
    _refreshing = true;
    _loadState = FinancialLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final FinancialStatus s = await _service.getStatus();
      _applyStatus(s);
      _loadState = FinancialLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = FinancialLoadState.error;
      _logger?.warning('Financial status refresh failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Creates a financial profile with the given default currency, then
  /// reloads profile + status and emits a one-shot `profile_created`
  /// notification.
  Future<void> createProfile({
    String defaultCurrency = 'NGN',
  }) async {
    if (_creating) return;
    _creating = true;
    _error = null;
    notifyListeners();
    try {
      final FinancialProfile created =
          await _service.createProfile(defaultCurrency: defaultCurrency);
      _maybeNotifyProfileCreated(created);
      await load();
    } on ApiException catch (e) {
      _error = e;
      _creating = false;
      _logger?.warning('Financial profile creation failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
        'defaultCurrency': defaultCurrency,
      });
      if (!_disposed) notifyListeners();
    }
  }

  void _applyStatus(FinancialStatus s) {
    _status = s;
    _balances = <String, Balance>{
      for (final Balance b in s.balances) b.currencyCode: b,
    };
  }

  void _maybeNotifyProfileCreated(FinancialProfile profile) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final int id = profile.entityId.hashCode & 0x7fffffff;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: id,
          title: 'Financial profile created',
          body: 'Your default currency is ${profile.defaultCurrency}.',
          channelId: FinanceNotificationChannel.system,
          priority: NotificationPriority.high,
          timestamp: _clock(),
          actionRoute: '/finance',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Polling lifecycle (EP-02-13 §5.5 / PV-05): no poll while `profile == null`
  // or a terminal `suspended`/`closed` status.
  // ---------------------------------------------------------------------------

  /// Whether a poll tick should run given the current profile/status.
  bool get _shouldPoll {
    final FinancialProfile? p = _profile;
    final FinancialStatus? s = _status;
    if (p == null || s == null) return false;
    final String ps = s.profileStatus;
    return ps != 'suspended' && ps != 'closed';
  }

  /// Enables polling (refresh loop) while a non-terminal profile exists.
  void startPolling() {
    _pollingEnabled = true;
    if (_shouldPoll) _ensurePollTimer();
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
    if (_pollingEnabled && _shouldPoll) _ensurePollTimer();
  }

  void _ensurePollTimer() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_onPollTick()),
    );
  }

  Future<void> _onPollTick() async {
    if (!_shouldPoll || _paused) {
      stopPolling();
      return;
    }
    await refreshStatus();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
