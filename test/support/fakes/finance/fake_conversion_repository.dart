// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/repositories/conversion_repository.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';

/// In-memory [ConversionRepository] for provider/widget tests (EP-02-15).
///
/// Serves scripted rates/conversions/history with call counters. Mirrors the
/// real repository's rate-integrity seam: every rate originates from the
/// injected [rateFor] callback (or [rates] map) and the conversion result
/// echoes the exact rate handed into [executeConversion]'s factory — never a
/// user-arbitrary value.
class FakeConversionRepository implements ConversionRepository {
  FakeConversionRepository({
    Map<String, double> rates = const <String, double>{},
    CurrencyConversion? conversion,
    List<CurrencyConversion> history = const <CurrencyConversion>[],
  })  : _rates = Map<String, double>.of(rates),
        _conversion = conversion,
        _history = List<CurrencyConversion>.of(history);

  final Map<String, double> _rates;
  CurrencyConversion? _conversion;
  final List<CurrencyConversion> _history;

  /// Thrown from every operation when set, exactly as the real repository
  /// surfaces typed [ApiException]s (e.g. `PLT003`/`PLT006`).
  ApiException? nextError;

  int getRateCallCount = 0;
  int previewCallCount = 0;
  int executeCallCount = 0;
  int historyCallCount = 0;
  String? lastFromCurrency;
  String? lastToCurrency;
  double? lastAmount;
  double? lastRateUsed;

  /// Replaces the conversion served by [executeConversion].
  void setConversion(CurrencyConversion conversion) => _conversion = conversion;

  /// Scripts the directed rate for `from|to`.
  void setRate(String from, String to, double rate) =>
      _rates['$from|$to'] = rate;

  @override
  Future<double> getRate({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    getRateCallCount++;
    lastFromCurrency = fromCurrency;
    lastToCurrency = toCurrency;
    if (nextError != null) throw nextError!;
    final double? rate = _rates['$fromCurrency|$toCurrency'];
    if (rate == null || rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    return rate;
  }

  @override
  Future<ConversionPreview> previewConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) async {
    previewCallCount++;
    lastFromCurrency = fromCurrency;
    lastToCurrency = toCurrency;
    lastAmount = amount;
    if (nextError != null) throw nextError!;
    final double? rate = _rates['$fromCurrency|$toCurrency'];
    if (rate == null || rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    final double gross = amount * rate;
    return ConversionPreview(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      fromAmount: amount,
      grossAmount: gross,
      fee: 0,
      toAmount: gross,
      exchangeRate: rate,
    );
  }

  @override
  Future<CurrencyConversion> executeConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) async {
    executeCallCount++;
    lastFromCurrency = fromCurrency;
    lastToCurrency = toCurrency;
    lastAmount = amount;
    if (nextError != null) throw nextError!;
    final double? rate = _rates['$fromCurrency|$toCurrency'];
    if (rate == null || rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    lastRateUsed = rate;
    return _conversion ??
        seedConversionEntity(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          fromAmount: amount,
          toAmount: amount * rate,
          exchangeRate: rate,
        );
  }

  @override
  Future<List<CurrencyConversion>> getHistory() async {
    historyCallCount++;
    if (nextError != null) throw nextError!;
    return List<CurrencyConversion>.unmodifiable(_history);
  }
}

/// Fixture builder for a `financial_conversions` domain entity.
CurrencyConversion seedConversionEntity({
  String id = 'conversion-1',
  String entityId = 'u1',
  String fromCurrency = 'NGN',
  String toCurrency = 'USD',
  double fromAmount = 50000,
  double toAmount = 35,
  double exchangeRate = 0.0007,
  double fee = 0,
  String status = 'completed',
  DateTime? createdAt,
}) =>
    CurrencyConversion(
      id: id,
      entityId: entityId,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      fromAmount: fromAmount,
      toAmount: toAmount,
      exchangeRate: exchangeRate,
      fee: fee,
      status: status,
      completedAt: createdAt,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
    );