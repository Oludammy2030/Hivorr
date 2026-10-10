// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [EarningsRepository] consumed by [EarningsProvider] and
/// [TransactionHistoryProvider] (EP-03-16).
///
/// Delegates data operations to the repository. Adds PII-safe structured
/// [HivorrLogger] output (currency code and row counts only — never amounts,
/// entity ids, or descriptions) and `finance.earnings.*` [PerformanceTracer]
/// spans (mirrors `FinancialService`
/// `lib/systems/finance/services/financial_service.dart:22-139`).
/// Read-only: no method here writes ledger, balance, escrow, or contract
/// state, and none aggregates — the RPCs remain the sole authority
/// (AGENT.md Rule 4).
class ServiceEarningsService {
  ServiceEarningsService({
    required EarningsRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _repository = repository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final EarningsRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;

  /// PII redactor for structured log context (entity ids stay redacted).
  final PiiRedactor _redactor;

  /// The supported currency codes, data-driven from
  /// `financial_supported_currencies`.
  static List<String> get supportedCodes => SupportedCurrency.codes.toList();

  /// Whether [currencyCode] is in the supported set.
  static bool isCurrencySupported(String currencyCode) =>
      SupportedCurrency.isSupported(currencyCode);

  /// Fetches the server-aggregated earnings summary for [currencyCode].
  Future<EarningsSummary> getSummary(String currencyCode) =>
      _tracedAndLogged('finance.earnings.summary.get', () async {
        final EarningsSummary summary = await _repository.getSummary(
          currencyCode,
        );
        _logger?.info('Earnings summary fetched', <String, Object?>{
          'currencyCode': currencyCode,
          'bucketCount': summary.monthly.length,
          'hasFrozen': summary.hasFrozen,
        });
        return summary;
      });

  /// Fetches one keyset-paginated history page.
  Future<EarningsTransactionPage> listHistory({
    required String currencyCode,
    String type = EarningsHistoryFilter.all,
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  }) => _tracedAndLogged('finance.earnings.history.list', () async {
    final EarningsTransactionPage page = await _repository.listTransactions(
      currencyCode: currencyCode,
      type: type,
      contractId: contractId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
      cursor: cursor,
    );
    _logger?.info('Earnings history page fetched', <String, Object?>{
      'currencyCode': currencyCode,
      'type': type,
      'itemCount': page.items.length,
      'hasMore': page.hasMore,
      'contractId': contractId == null ? null : _redactor.redact(contractId),
    });
    return page;
  });

  /// Fetches summaries for every supported currency, sequentially.
  ///
  /// The [defaultFirst] currency leads (default-currency-first convention
  /// per `BalanceOverviewCard`); failures for one currency never abort the
  /// rest — the caller decides how to surface partial windows.
  Future<Map<String, EarningsSummary>> summaryForAllCurrencies({
    String defaultFirst = 'NGN',
  }) => _tracedAndLogged('finance.earnings.summary.all', () async {
    final Map<String, EarningsSummary> out = <String, EarningsSummary>{};
    final List<String> ordered = <String>[
      defaultFirst,
      for (final String code in SupportedCurrency.codes)
        if (code != defaultFirst) code,
    ];
    for (final String code in ordered) {
      try {
        out[code] = await _repository.getSummary(code);
      } on Object catch (error) {
        _logger?.warning('Earnings summary skipped', <String, Object?>{
          'currencyCode': code,
          'error': '$error',
        });
      }
    }
    return out;
  });

  /// Clears all `finance:earnings:` cache windows.
  Future<void> invalidateCache() =>
      _tracedAndLogged('finance.earnings.cache.invalidate', () async {
        await _repository.invalidateCache();
      });

  /// Wraps [action] in a `finance.earnings.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'finance');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}
