// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/repositories/conversion_repository.dart';
import 'package:hivorr/systems/finance/helpers/conversion_formatter.dart';
import 'package:hivorr/systems/finance/models/conversion_pair.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin facade over [ConversionRepository] consumed by [ConversionProvider]
/// and future EP-02-16/EP-02-14 consumers (EP-02-15 §5.5).
///
/// Exposes flag-gated [availablePairs] from the single rate authority
/// ([WalletConversionPairsConfig]), delegates data operations to the
/// repository (no business rules bypassed), and formats previews
/// locale-aware via `BalanceFormatter` (DoD FV-24/FV-25). Adds PII-safe
/// [HivorrLogger] output and `finance.conversion.*` [PerformanceTracer] spans.
class ConversionService {
  ConversionService({
    required ConversionRepository repository,
    required WalletConversionPairsConfig pairsConfig,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repository = repository,
        _pairsConfig = pairsConfig,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final ConversionRepository _repository;
  final WalletConversionPairsConfig _pairsConfig;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// The ordered, directed pairs the entity can convert between — each seeded
  /// base pair yields both directions (12 pairs for the 6 seeded pairs).
  /// Empty while conversion is flag-gated off.
  List<ConversionPair> get availablePairs => _pairsConfig.availablePairs();

  /// Returns the current trusted rate for `fromCurrency`→`toCurrency`.
  Future<double> getRate({
    required String fromCurrency,
    required String toCurrency,
  }) =>
      _tracedAndLogged(
        'finance.conversion.rate.get',
        () async {
          final double rate = await _repository.getRate(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
          );
          _logger?.info('Conversion rate fetched', <String, Object?>{
            'fromCurrency': fromCurrency,
            'toCurrency': toCurrency,
            'rate': rate,
          });
          return rate;
        },
      );

  /// Computes a local, zero-RPC conversion estimate.
  Future<ConversionPreview> previewConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) =>
      _tracedAndLogged(
        'finance.conversion.preview',
        () async {
          final preview = await _repository.previewConversion(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            amount: amount,
          );
          _logger?.info('Conversion preview computed', <String, Object?>{
            'fromCurrency': preview.fromCurrency,
            'toCurrency': preview.toCurrency,
            'fromAmount': preview.fromAmount,
            'toAmount': preview.toAmount,
            'fee': preview.fee,
          });
          return preview;
        },
      );

  /// Executes a conversion via `financial_convert_currency`, then refreshes
  /// balances (repository-side best-effort).
  Future<CurrencyConversion> executeConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) =>
      _tracedAndLogged(
        'finance.conversion.execute',
        () async {
          final conversion = await _repository.executeConversion(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            amount: amount,
          );
          _logger?.info('Currency conversion executed', <String, Object?>{
            'conversionId': _redactor.redact(conversion.id),
            'fromCurrency': conversion.fromCurrency,
            'toCurrency': conversion.toCurrency,
            'fromAmount': conversion.fromAmount,
            'toAmount': conversion.toAmount,
            'status': conversion.status,
          });
          return conversion;
        },
      );

  /// Fetches the caller's conversion history.
  Future<List<CurrencyConversion>> getHistory() =>
      _tracedAndLogged(
        'finance.conversion.history.get',
        () async {
          final history = await _repository.getHistory();
          _logger?.info('Conversion history fetched', <String, Object?>{
            'count': history.length,
          });
          return history;
        },
      );

  /// Locale-aware preview string: `'₦50,000.00 → $35.00'`.
  String formatPreview(ConversionPreview preview) =>
      ConversionFormatter.preview(preview);

  /// Rate copy for display: `'1 NGN = 0.0007 USD'`.
  String formatRate(
    double rate, {
    required String fromCurrency,
    required String toCurrency,
  }) =>
      ConversionFormatter.rate(
        rate,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );

  /// Wraps [action] in a `finance.conversion.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'finance');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
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