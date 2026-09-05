// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/helpers/conversion_formatter.dart';
import 'package:hivorr/systems/finance/models/conversion_pair.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';
import 'package:hivorr/systems/finance/services/conversion_service.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';

/// Notification channel used for conversion events (EP-02-15 §7.5).
abstract final class ConversionNotificationChannel {
  const ConversionNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the conversion provider (EP-02-15 §5.6).
enum ConversionLoadState {
  /// No load attempted yet.
  idle,

  /// A history/rate load is in flight.
  loading,

  /// The latest load succeeded.
  loaded,

  /// The latest load failed.
  error,
}

/// Provider exposing currency-conversion state to the widget tree (EP-02-15).
///
/// Depends only on the [ConversionService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the current pair selection (`from`/`to`),
/// amount, the local zero-RPC preview, the last executed conversion, and the
/// history list — plus a [WidgetsBindingObserver] lifecycle gate (no
/// background history refreshes), a `_disposed` guard, and a one-shot
/// "Currency converted" [HivorrNotification] hook (mirrors `FinancialProvider`)
/// / `EscrowProvider` (§5.6).
class ConversionProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [financialService] enables the authoritative post-execute balance
  /// refresh; [notificationProvider] enables the conversion notification hook;
  /// [clock] is injectable for deterministic tests.
  ConversionProvider({
    required ConversionService service,
    FinancialService? financialService,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  })  : _service = service,
        _financialService = financialService,
        _logger = logger,
        _notificationProvider = notificationProvider,
        _clock = clock ?? DateTime.now {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No live binding yet (data-layer construction in bootstrap).
    }
  }

  final ConversionService _service;
  final FinancialService? _financialService;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final DateTime Function() _clock;

  String? _fromCurrency;
  String? _toCurrency;
  double _amount = 0;
  double? _rate;
  bool _rateLoading = false;
  bool _rateUnavailable = false;
  ConversionPreview? _preview;
  CurrencyConversion? _lastConversion;
  List<CurrencyConversion> _history = const <CurrencyConversion>[];
  ConversionLoadState _loadState = ConversionLoadState.idle;
  bool _previewing = false;
  bool _converting = false;
  ApiException? _error;
  bool _paused = false;
  bool _disposed = false;

  /// Currently selected source currency code, or `null`.
  String? get fromCurrency => _fromCurrency;

  /// Currently selected destination currency code, or `null`.
  String? get toCurrency => _toCurrency;

  /// The amount the user intends to convert (`> 0`).
  double get amount => _amount;

  /// The trusted rate for the current pair, or `null` when none is loaded.
  double? get rate => _rate;

  /// Whether a rate fetch is in flight.
  bool get isRateLoading => _rateLoading;

  /// Whether the pair has no configured rate (`ConversionRateUnavailableException`).
  bool get isRateUnavailable => _rateUnavailable;

  /// The latest local estimate, or `null` while unavailable.
  ConversionPreview? get preview => _preview;

  /// The most recent executed conversion, or `null`.
  CurrencyConversion? get lastConversion => _lastConversion;

  /// The loaded conversion history (reverse-chronological).
  List<CurrencyConversion> get history => _history;

  /// The directed pairs the entity can convert between (flag-gated).
  List<ConversionPair> get availablePairs => _service.availablePairs;

  /// Whether any flag-gated, valid pairs are discoverable. When `false` the
  /// screen renders an empty state instead of the conversion form.
  bool get isConversionEnabled => availablePairs.isNotEmpty;

  /// The history/load lifecycle state.
  ConversionLoadState get loadState => _loadState;

  /// Whether a history/rate load is in flight.
  bool get isLoading => _loadState == ConversionLoadState.loading;

  /// Whether a preview computation is in flight.
  bool get isPreviewing => _previewing;

  /// Whether a conversion execution is in flight.
  bool get isConverting => _converting;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Whether the current selection supports a preview + execution.
  bool get canConvert {
    final String? from = _fromCurrency;
    final String? to = _toCurrency;
    return from != null &&
        to != null &&
        from != to &&
        _amount > 0 &&
        _amount.isFinite;
  }

  /// Selects the source currency, clearing any stale estimate and rate.
  void setSource(String currencyCode) {
    if (_fromCurrency == currencyCode) return;
    _fromCurrency = currencyCode;
    _clearTransient();
  }

  /// Selects the destination currency, clearing any stale estimate and rate.
  ///
  /// Self-pairs are rejected at the repository/UI validation layer.
  void setDestination(String currencyCode) {
    if (_toCurrency == currencyCode) return;
    _toCurrency = currencyCode;
    _clearTransient();
  }

  /// Sets the amount to convert, clearing any stale estimate.
  ///
  /// The trusted rate is pair-dependent and survives amount edits.
  void setAmount(double value) {
    if (_amount == value) return;
    _amount = value;
    _clearTransient(clearRate: false);
  }

  /// Fetches the trusted rate for the current pair (rate card).
  ///
  /// Distinct from [preview]: independent of the amount, surfaces the
  /// rate-unavailable state specifically (rather than a generic operation
  /// error), driving `ConversionRateCard` per FV-34.
  Future<void> loadRate() async {
    final String? from = _fromCurrency;
    final String? to = _toCurrency;
    if (from == null || to == null || from == to || _rateLoading) return;
    _rateLoading = true;
    _rate = null;
    _rateUnavailable = false;
    notifyListeners();
    try {
      _rate = await _service.getRate(
        fromCurrency: from,
        toCurrency: to,
      );
    } on ConversionRateUnavailableException {
      _rateUnavailable = true;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Conversion rate load failed', <String, Object?>{
        'fromCurrency': from,
        'toCurrency': to,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _rateLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Computes a local, zero-RPC estimate for the current selection.
  Future<void> refreshPreview() async {
    final String? from = _fromCurrency;
    final String? to = _toCurrency;
    if (from == null || to == null || from == to || _previewing) return;
    _previewing = true;
    _error = null;
    notifyListeners();
    try {
      final ConversionPreview estimate = await _service.previewConversion(
        fromCurrency: from,
        toCurrency: to,
        amount: _amount,
      );
      _preview = estimate;
      _rate = estimate.exchangeRate;
      _rateUnavailable = false;
    } on ApiException catch (e) {
      _preview = null;
      _error = e;
      _logger?.warning('Conversion preview failed', <String, Object?>{
        'fromCurrency': from,
        'toCurrency': to,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _previewing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Executes the current conversion, refreshes balances, and emits a
  /// one-shot "Currency converted" notification on success.
  Future<void> execute() async {
    final String? from = _fromCurrency;
    final String? to = _toCurrency;
    if (from == null || to == null || from == to || _converting) return;
    _converting = true;
    _error = null;
    notifyListeners();
    try {
      final CurrencyConversion conversion = await _service.executeConversion(
        fromCurrency: from,
        toCurrency: to,
        amount: _amount,
      );
      _lastConversion = conversion;
      unawaited(_maybeRefreshBalances());
      _maybeNotifyConverted(conversion);
      _logger?.info('Conversion executed', <String, Object?>{
        'fromCurrency': from,
        'toCurrency': to,
        'status': conversion.status,
      });
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Conversion execution failed', <String, Object?>{
        'fromCurrency': from,
        'toCurrency': to,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _converting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads conversion history (reverse-chronological). Returns early while a
  /// load is in flight or the app is backgrounded.
  Future<void> loadHistory() async {
    if (isLoading || _paused) return;
    _loadState = ConversionLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _history = await _service.getHistory();
      _loadState = ConversionLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = ConversionLoadState.error;
      _logger?.warning('Conversion history load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void _clearTransient({bool clearRate = true}) {
    _preview = null;
    if (clearRate) {
      _rate = null;
      _rateLoading = false;
      _rateUnavailable = false;
    }
    _error = null;
    if (!_disposed) notifyListeners();
  }

  /// Best-effort authoritative balance refresh (pull-to-refresh of the
  /// financial status). The conversion is already committed server-side, so a
  /// refresh failure must not surface as a conversion failure.
  Future<void> _maybeRefreshBalances() async {
    final FinancialService? service = _financialService;
    if (service == null) return;
    try {
      final FinancialStatus status = await service.getStatus();
      _logger?.info('Balances refreshed after conversion',
          <String, Object?>{
            'balanceCount': status.balances.length,
          });
    } on Object {
      // Best-effort — see method dartdoc.
    }
  }

  void _maybeNotifyConverted(CurrencyConversion conversion) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final String from = BalanceFormatter.formatBalance(
      conversion.fromAmount,
      conversion.fromCurrency,
    );
    final String to = BalanceFormatter.formatBalance(
      conversion.toAmount,
      conversion.toCurrency,
    );
    final String rate = ConversionFormatter.rate(
      conversion.exchangeRate,
      fromCurrency: conversion.fromCurrency,
      toCurrency: conversion.toCurrency,
    );
    final int id = conversion.id.hashCode & 0x7fffffff;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: id,
          title: 'Currency converted',
          body: '$from \u2192 $to ($rate)',
          channelId: ConversionNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/finance/convert',
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No background history refreshes (EP-02-15 §5.6 lifecycle gate).
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