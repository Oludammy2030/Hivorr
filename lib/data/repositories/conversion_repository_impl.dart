// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/conversion_remote_data_source.dart';
import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/data/mappers/conversion_mapper.dart';
import 'package:hivorr/data/models/currency_conversion_dto.dart';
import 'package:hivorr/data/repositories/conversion_repository.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';

/// Default implementation of [ConversionRepository] (EP-02-15 §5.4).
///
/// Every rate supplied to `financial_convert_currency` originates from the
/// injected [ConversionRateSource] — this implementation never accepts,
/// derives, or invents a rate on its own (single client rate authority). The
/// server rejects `p_rate <= 0` with `PLT003` (`1498`), and the client
/// validates the same invariant before any RPC attempt.
class ConversionRepositoryImpl implements ConversionRepository {
  ConversionRepositoryImpl({
    required ConversionRemoteDataSource remote,
    required ConversionRateSource rateSource,
    required FinancialRepository financialRepository,
    double fee = 0,
  })  : _remote = remote,
        _rateSource = rateSource,
        _financialRepository = financialRepository,
        _fee = fee;

  final ConversionRemoteDataSource _remote;
  final ConversionRateSource _rateSource;
  final FinancialRepository _financialRepository;

  /// Client-side fee estimate; `0` while the server applies `v_fee := 0`
  /// (`financial_convert_currency:1479`). The preview uses this for display;
  /// the executed `toAmount` is always the server-computed value (`1558-1561`).
  final double _fee;

  @override
  Future<double> getRate({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    _validatePair(fromCurrency, toCurrency);
    return _rateSource.rateFor(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
  }

  @override
  Future<ConversionPreview> previewConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) async {
    _validatePair(fromCurrency, toCurrency);
    _validateAmount(amount);
    // The trusted rate comes from the seam — never user input. Zero RPCs:
    // preview is pure local math feeding the display-only estimate.
    final double rate = await _rateSource.rateFor(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
    if (rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    final double gross = amount * rate;
    final double net = gross - _fee;
    return ConversionPreview(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      fromAmount: amount,
      grossAmount: gross,
      fee: _fee,
      toAmount: net,
      exchangeRate: rate,
    );
  }

  @override
  Future<CurrencyConversion> executeConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  }) async {
    _validatePair(fromCurrency, toCurrency);
    _validateAmount(amount);
    final double rate = await _rateSource.rateFor(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
    if (rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    final CurrencyConversionDto dto = await _remote.convertCurrency(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      amount: amount,
      rate: rate,
    );
    final CurrencyConversion conversion = ConversionMapper.conversionToEntity(dto);
    await _refreshBalancesBestEffort();
    return conversion;
  }

  @override
  Future<List<CurrencyConversion>> getHistory() async {
    final List<CurrencyConversionDto> rows = await _remote.getHistory();
    return rows.map(ConversionMapper.conversionToEntity).toList(growable: false);
  }

  /// Best-effort post-execution balance refresh via `financial_status_get`.
  ///
  /// The conversion is already committed server-side under `FOR UPDATE` when
  /// this runs, so a refresh failure must **not** surface as a conversion
  /// failure (that would tempt a user to re-execute and double-convert). The
  /// authoritative balance refresh that drives the UI lives in the provider;
  /// this repository-side re-read keeps the read model warm.
  Future<void> _refreshBalancesBestEffort() async {
    try {
      await _financialRepository.getStatus();
    } on Object {
      // Intentionally swallowed — see method dartdoc (never fail a completed
      // server-authoritative conversion on a read-model refresh).
    }
  }

  void _validatePair(String fromCurrency, String toCurrency) {
    if (!SupportedCurrency.isSupported(fromCurrency) ||
        !SupportedCurrency.isSupported(toCurrency)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Unsupported currency. Supported currencies are NGN, GHS, USD, GBP.',
        code: 'PLT003',
      );
    }
    if (fromCurrency == toCurrency) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Source and destination currencies must differ.',
        code: 'PLT003',
      );
    }
  }

  void _validateAmount(double amount) {
    if (amount <= 0 || !amount.isFinite) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Conversion amount must be greater than zero.',
        code: 'PLT003',
      );
    }
  }
}