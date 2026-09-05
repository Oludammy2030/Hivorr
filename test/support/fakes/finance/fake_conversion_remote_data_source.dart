// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/conversion_remote_data_source.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';

/// In-memory [ConversionRemoteDataSource] for provider/repository/service
/// tests (EP-02-15).
///
/// Serves scripted DTOs with call counters; set [nextError] to exercise
/// failure paths exactly as the real datasource throws [ApiException]. The
/// conversion result echoes the requested `amount`/`rate` so callers can
/// assert the exact rate handed to the seam (rate-integrity, DoD SV-01).
class FakeConversionRemoteDataSource implements ConversionRemoteDataSource {
  FakeConversionRemoteDataSource({
    CurrencyConversionDto? conversion,
    List<CurrencyConversionDto> history = const <CurrencyConversionDto>[],
    this.historyReadEnabled = true,
  })  : _conversion = conversion,
        _history = List<CurrencyConversionDto>.of(history);

  CurrencyConversionDto? _conversion;
  final List<CurrencyConversionDto> _history;

  /// Whether the REST history read seam is enabled on this fake.
  final bool historyReadEnabled;

  ApiException? nextError;
  int convertCallCount = 0;
  int historyCallCount = 0;
  String? lastFromCurrency;
  String? lastToCurrency;
  double? lastAmount;
  double? lastRate;

  /// Replaces the conversion DTO served by [convertCurrency].
  void setConversion(CurrencyConversionDto conversion) =>
      _conversion = conversion;

  @override
  Future<CurrencyConversionDto> convertCurrency({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
    required double rate,
  }) async {
    convertCallCount++;
    lastFromCurrency = fromCurrency;
    lastToCurrency = toCurrency;
    lastAmount = amount;
    lastRate = rate;
    if (nextError != null) throw nextError!;
    return _conversion ??
        CurrencyConversionDto.fromRpc(
          conversionId: 'conversion-rpc-1',
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          fromAmount: amount,
          toAmount: amount * rate,
          rate: rate,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        );
  }

  @override
  Future<List<CurrencyConversionDto>> getHistory() async {
    historyCallCount++;
    if (nextError != null) throw nextError!;
    if (!historyReadEnabled) return const <CurrencyConversionDto>[];
    return List<CurrencyConversionDto>.unmodifiable(_history);
  }
}

/// Fixture builder for a `financial_conversions` history row DTO.
CurrencyConversionDto seedConversionDto({
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
    CurrencyConversionDto(
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